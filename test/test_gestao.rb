# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/empresta_comunidade/gestao"

class GestaoTest < Minitest::Test
  DIA = Date.new(2026, 11, 8)

  def setup
    @gestao = EmprestaComunidade::Gestao.new(hoje: -> { DIA })
    @gestao.cadastrar_participante("ana", " Ana Silva ", contato: "ana@example.test")
    @gestao.cadastrar_participante("bia", "Bia")
    @gestao.cadastrar_participante("caio", "Caio")
    @gestao.cadastrar_item("furadeira", " Furadeira ", categoria: "ferramenta", descricao: "Sem fio")
    @gestao.cadastrar_item("livro", "Livro Ruby", categoria: "livro")
    @gestao.cadastrar_item("camera", "Câmera", categoria: "equipamento")
    @gestao.cadastrar_item("kit", "Kit", categoria: "outro")
  end

  def test_registers_participants_with_normalized_fields
    ana = @gestao.participantes.find { |p| p["id"] == "ana" }
    assert_equal "Ana Silva", ana["nome"]
    assert_equal "ana@example.test", ana["contato"]
    assert_equal %w[ana bia caio], @gestao.participantes.map { |p| p["id"] }
  end

  def test_rejects_duplicate_participant_without_changing_state
    before = @gestao.participantes
    assert_raises(ArgumentError) { @gestao.cadastrar_participante("ana", "Outra Ana") }
    assert_equal before, @gestao.participantes
  end

  def test_rejects_empty_ids_names_and_contacts
    ["", " ", nil, 42].each do |id|
      assert_raises(ArgumentError) { @gestao.cadastrar_participante(id, "Nome") }
    end
    assert_raises(ArgumentError) { @gestao.cadastrar_participante("novo", "") }
    assert_raises(ArgumentError) { @gestao.cadastrar_participante("novo", "Nome", contato: " ") }
  end

  def test_rejects_oversized_text_fields
    assert_raises(ArgumentError) { @gestao.cadastrar_participante("x" * 201, "Nome") }
    assert_raises(ArgumentError) { @gestao.cadastrar_item("novo", "N" * 201) }
  end

  def test_registers_items_with_categories_and_descriptions
    item = @gestao.itens.find { |i| i["id"] == "furadeira" }
    assert_equal "Furadeira", item["nome"]
    assert_equal "ferramenta", item["categoria"]
    assert_equal "Sem fio", item["descricao"]
    assert item["disponivel"]
    assert_equal 0, item["reservas"]
  end

  def test_rejects_duplicate_items_and_invalid_categories
    assert_raises(ArgumentError) { @gestao.cadastrar_item("livro", "Duplicado") }
    assert_raises(ArgumentError) { @gestao.cadastrar_item("novo", "Teste", categoria: "desconhecida") }
    assert_equal 4, @gestao.itens.length
  end

  def test_searches_by_term_category_and_availability
    assert_equal ["furadeira"], @gestao.pesquisar(termo: "SEM FIO").map { |i| i["id"] }
    assert_equal ["livro"], @gestao.pesquisar(categoria: "LIVRO").map { |i| i["id"] }
    assert_equal 4, @gestao.pesquisar(disponivel: true).length
    @gestao.emprestar("livro", "ana")
    assert_equal ["livro"], @gestao.pesquisar(disponivel: false).map { |i| i["id"] }
    assert_equal [], @gestao.pesquisar(categoria: "livro", disponivel: true)
  end

  def test_search_rejects_invalid_filters
    assert_raises(ArgumentError) { @gestao.pesquisar(categoria: "carro") }
    assert_raises(ArgumentError) { @gestao.pesquisar(disponivel: "sim") }
    assert_raises(ArgumentError) { @gestao.pesquisar(termo: 3) }
  end

  def test_lending_sets_due_date_and_marks_item_unavailable
    loan = @gestao.emprestar("livro", "ana")
    assert_equal "ana", loan["participante_id"]
    assert_equal "2026-11-08", loan["retirada"]
    assert_equal "2026-11-22", loan["prazo"]
    assert_equal 0, loan["renovacoes"]
    refute @gestao.catalogo.disponivel?("livro")
  end

  def test_custom_lending_period_and_date
    loan = @gestao.emprestar("livro", "bia", dias: 30, data: DIA - 2)
    assert_equal "2026-12-06", loan["prazo"]
    assert_equal "2026-11-06", loan["retirada"]
  end

  def test_rejects_unknown_participant_and_item
    assert_raises(ArgumentError) { @gestao.emprestar("livro", "desconhecido") }
    assert_raises(ArgumentError) { @gestao.emprestar("inexistente", "ana") }
    assert @gestao.catalogo.disponivel?("livro")
  end

  def test_rejects_invalid_lending_periods_and_dates
    [0, -1, 91, 1.5, "14", nil].each do |dias|
      assert_raises(ArgumentError) { @gestao.emprestar("livro", "ana", dias: dias) }
    end
    assert_raises(ArgumentError) { @gestao.emprestar("livro", "ana", data: "2026-11-08") }
    assert @gestao.catalogo.disponivel?("livro")
  end

  def test_enforces_three_active_loans_per_participant
    %w[livro camera kit].each { |id| @gestao.emprestar(id, "ana") }
    assert_raises(ArgumentError) { @gestao.emprestar("furadeira", "ana") }
    assert_equal 3, @gestao.emprestimos_de("ana").length
    assert @gestao.catalogo.disponivel?("furadeira")
  end

  def test_prevents_duplicate_lending
    @gestao.emprestar("livro", "ana")
    assert_raises(ArgumentError) { @gestao.emprestar("livro", "bia") }
    assert_equal 1, @gestao.emprestimos_ativos.length
  end

  def test_return_restores_availability_and_records_date
    @gestao.emprestar("livro", "ana")
    devolvido = @gestao.devolver("livro", data: DIA + 3)
    assert_equal "2026-11-11", devolvido["devolucao"]
    assert @gestao.catalogo.disponivel?("livro")
    assert_empty @gestao.emprestimos_ativos
    assert_equal 1, @gestao.historico(tipo: "devolvido").length
  end

  def test_return_rejects_unknown_or_duplicate_return
    assert_raises(ArgumentError) { @gestao.devolver("livro") }
    @gestao.emprestar("livro", "ana")
    @gestao.devolver("livro")
    assert_raises(ArgumentError) { @gestao.devolver("livro") }
  end

  def test_return_rejects_date_before_checkout
    @gestao.emprestar("livro", "ana")
    assert_raises(ArgumentError) { @gestao.devolver("livro", data: DIA - 1) }
    refute @gestao.catalogo.disponivel?("livro")
  end

  def test_overdue_is_exclusive_of_due_date_and_sorted
    @gestao.emprestar("livro", "ana", dias: 2)
    @gestao.emprestar("camera", "bia", dias: 1)
    assert_empty @gestao.atrasados(data: DIA + 1)
    late = @gestao.atrasados(data: DIA + 3)
    assert_equal %w[camera livro], late.map { |loan| loan["item_id"] }
    assert_equal [2, 1], late.map { |loan| loan["dias_atraso"] }
  end

  def test_renews_loan_without_changing_original_checkout
    @gestao.emprestar("livro", "ana", dias: 5)
    renewed = @gestao.renovar("livro", "ana", dias: 7, data: DIA + 2)
    assert_equal "2026-11-20", renewed["prazo"]
    assert_equal "2026-11-08", renewed["retirada"]
    assert_equal 1, renewed["renovacoes"]
    assert_empty @gestao.atrasados(data: DIA + 10)
    assert_equal Date.new(2026, 11, 20), @gestao.catalogo.emprestimos_ativos.first.prazo
  end

  def test_renewal_rejects_wrong_borrower
    @gestao.emprestar("livro", "ana")
    assert_raises(ArgumentError) { @gestao.renovar("livro", "bia") }
    assert_equal 0, @gestao.emprestimos_ativos.first["renovacoes"]
  end

  def test_renewal_rejects_overdue_loans
    @gestao.emprestar("livro", "ana", dias: 2)
    assert_raises(ArgumentError) { @gestao.renovar("livro", "ana", data: DIA + 3) }
  end

  def test_renewal_is_limited_to_two
    @gestao.emprestar("livro", "ana")
    2.times { @gestao.renovar("livro", "ana") }
    assert_raises(ArgumentError) { @gestao.renovar("livro", "ana") }
    assert_equal 2, @gestao.emprestimos_ativos.first["renovacoes"]
  end

  def test_reservation_waitlist_is_fifo
    @gestao.emprestar("livro", "ana")
    assert_equal ["bia"], @gestao.reservar("livro", "bia")
    assert_equal %w[bia caio], @gestao.reservar("livro", "caio")
    @gestao.devolver("livro")
    assert_raises(ArgumentError) { @gestao.emprestar("livro", "caio") }
    @gestao.emprestar("livro", "bia")
    assert_equal ["caio"], @gestao.lista_espera("livro")
  end

  def test_cannot_reserve_available_or_own_item
    assert_raises(ArgumentError) { @gestao.reservar("livro", "bia") }
    @gestao.emprestar("livro", "ana")
    assert_raises(ArgumentError) { @gestao.reservar("livro", "ana") }
  end

  def test_prevents_duplicate_reservations
    @gestao.emprestar("livro", "ana")
    @gestao.reservar("livro", "bia")
    assert_raises(ArgumentError) { @gestao.reservar("livro", "bia") }
    assert_equal ["bia"], @gestao.lista_espera("livro")
  end

  def test_cancels_reservation_without_affecting_others
    @gestao.emprestar("livro", "ana")
    @gestao.reservar("livro", "bia")
    @gestao.reservar("livro", "caio")
    assert_equal ["caio"], @gestao.cancelar_reserva("livro", "bia")
    assert_raises(ArgumentError) { @gestao.cancelar_reserva("livro", "bia") }
  end

  def test_pending_reservation_blocks_renewal
    @gestao.emprestar("livro", "ana")
    @gestao.reservar("livro", "bia")
    assert_raises(ArgumentError) { @gestao.renovar("livro", "ana") }
    assert_equal "2026-11-22", @gestao.emprestimos_ativos.first["prazo"]
  end

  def test_statistics_reflect_loans_overdue_and_reservations
    @gestao.emprestar("livro", "ana", dias: 1)
    @gestao.reservar("livro", "bia")
    stats = @gestao.estatisticas(data: DIA + 3)
    assert_equal 3, stats["participantes"]
    assert_equal 4, stats["itens"]
    assert_equal 3, stats["disponiveis"]
    assert_equal 1, stats["emprestados"]
    assert_equal 1, stats["atrasados"]
    assert_equal 1, stats["reservas"]
  end

  def test_csv_export_includes_header_and_active_loan
    @gestao.emprestar("livro", "ana")
    csv = CSV.parse(@gestao.exportar_csv, headers: true)
    assert_equal 1, csv.length
    assert_equal "livro", csv.first["item_id"]
    assert_equal "Livro Ruby", csv.first["nome"]
    assert_equal "ana", csv.first["participante_id"]
  end

  def test_csv_export_is_valid_when_no_loans_exist
    csv = CSV.parse(@gestao.exportar_csv, headers: true)
    assert_empty csv
    assert_includes csv.headers, "prazo"
  end

  def test_snapshots_do_not_expose_internal_mutable_state
    participants = @gestao.participantes
    participants.first["nome"] = "Adulterado"
    @gestao.itens.first["nome"] = "Adulterado"
    @gestao.snapshot["participantes"].clear
    assert_equal "Ana Silva", @gestao.participantes.first["nome"]
    assert_equal 4, @gestao.itens.size
  end

  def test_history_filters_by_type_and_item
    @gestao.emprestar("livro", "ana")
    @gestao.devolver("livro")
    assert_equal 1, @gestao.historico(tipo: "emprestado", item_id: "livro").length
    assert_equal 1, @gestao.historico(tipo: "devolvido", participante_id: "ana").length
    assert_equal [], @gestao.historico(tipo: "devolvido", item_id: "camera")
  end

  def test_persistence_roundtrip_preserves_loan_and_waitlist
    @gestao.emprestar("livro", "ana", dias: 4)
    @gestao.reservar("livro", "bia")
    @gestao.renovar("camera", "bia") if false # no-op: unrelated item stays available
    Dir.mktmpdir do |dir|
      path = File.join(dir, "estado.json")
      assert_equal path, @gestao.salvar(path)
      restored = EmprestaComunidade::Gestao.carregar(path, hoje: -> { DIA })
      assert_equal @gestao.snapshot, restored.snapshot
      assert_equal ["bia"], restored.lista_espera("livro")
      restored.devolver("livro")
      restored.emprestar("livro", "bia")
      assert_equal "bia", restored.emprestimos_ativos.first["participante_id"]
    end
  end

  def test_persistence_preserves_renewal_count
    @gestao.emprestar("livro", "ana")
    @gestao.renovar("livro", "ana")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "estado.json")
      @gestao.salvar(path)
      restored = EmprestaComunidade::Gestao.carregar(path, hoje: -> { DIA })
      assert_equal 1, restored.emprestimos_ativos.first["renovacoes"]
      assert_equal "2026-11-29", restored.emprestimos_ativos.first["prazo"]
    end
  end

  def test_invalid_json_and_schema_are_rejected
    Dir.mktmpdir do |dir|
      path = File.join(dir, "estado.json")
      File.write(path, "{não é json")
      assert_raises(ArgumentError) { EmprestaComunidade::Gestao.carregar(path) }
      File.write(path, '{"versao":2}')
      assert_raises(ArgumentError) { EmprestaComunidade::Gestao.carregar(path) }
      File.write(path, '{"versao":1,"participantes":[],"itens":[],"ativos":[],"filas":[],"historico":[]}')
      assert_raises(ArgumentError) { EmprestaComunidade::Gestao.carregar(path) }
    end
  end

  def test_legacy_catalog_remains_compatible
    catalogo = Catalogo.new
    item = catalogo.cadastrar("antigo", "Item antigo")
    assert_same item, catalogo.emprestar("antigo")
    catalogo.devolver(item)
    assert catalogo.disponivel?("antigo")
  end
end
