# frozen_string_literal: true
require "minitest/autorun"
require_relative "../lib/empresta_comunidade"

class CatalogoTest < Minitest::Test
  def test_controls_lending_and_return
    catalog = Catalogo.new
    catalog.cadastrar("ferramenta-1", " Furadeira ")
    item = catalog.emprestar("ferramenta-1")
    refute catalog.disponivel?("ferramenta-1")
    assert_equal "Furadeira", item.nome
    catalog.devolver(item)
    assert catalog.disponivel?("ferramenta-1")
  end

  def test_rejects_duplicate_lending
    catalog = Catalogo.new
    catalog.cadastrar("livro-1", "Livro")
    catalog.emprestar("livro-1")
    assert_raises(ArgumentError) { catalog.emprestar("livro-1") }
  end

  def test_tracks_late_loans_and_clears_them_after_return
    catalog = Catalogo.new
    first = catalog.cadastrar("furadeira-1", "Furadeira")
    catalog.cadastrar("livro-1", "Livro")
    day = Date.new(2026, 11, 3)

    assert_same first, catalog.emprestar(
      "furadeira-1", pessoa: " Ana ", data_emprestimo: day, prazo: day + 7
    )
    catalog.emprestar(
      "livro-1", pessoa: "Bruno", data_emprestimo: day, prazo: day + 3
    )

    assert_empty catalog.emprestimos_atrasados(day + 3)
    assert_equal ["livro-1"], catalog.emprestimos_atrasados(day + 4).map { |loan| loan.item.id }
    late = catalog.emprestimos_atrasados(day + 8)
    assert_equal ["livro-1", "furadeira-1"], late.map { |loan| loan.item.id }
    assert_equal "Ana", late.last.pessoa
    assert_raises(FrozenError) { late.clear }
    assert_raises(FrozenError) { late.last.prazo = day }

    catalog.devolver(first)
    assert_equal ["livro-1"], catalog.emprestimos_atrasados(day + 8).map { |loan| loan.item.id }
    assert catalog.disponivel?("furadeira-1")
  end

  def test_rejects_duplicate_registration_and_forged_returns
    catalog = Catalogo.new
    item = catalog.cadastrar("camera-1", "Câmera")
    assert_raises(ArgumentError) { catalog.cadastrar("camera-1", "Outra câmera") }
    assert_raises(ArgumentError) { catalog.devolver(item) }

    catalog.emprestar("camera-1")
    assert_raises(ArgumentError) { catalog.cadastrar("camera-1", "Novo nome") }
    assert_raises(ArgumentError) { catalog.devolver(Item.new(id: "camera-1", nome: "Câmera")) }
    refute catalog.disponivel?("camera-1")
    catalog.devolver(item)
    assert catalog.disponivel?("camera-1")
    assert_raises(ArgumentError) { catalog.devolver(item) }
  end

  def test_rejects_incomplete_or_invalid_loan_details_without_state_change
    catalog = Catalogo.new
    item = catalog.cadastrar("kit-1", "Kit")
    day = Date.new(2026, 11, 3)
    assert_raises(ArgumentError) { catalog.emprestar("kit-1", pessoa: "Ana") }
    assert_raises(ArgumentError) do
      catalog.emprestar("kit-1", pessoa: "Ana", data_emprestimo: day, prazo: day - 1)
    end
    assert_raises(ArgumentError) do
      catalog.emprestar("kit-1", pessoa: " ", data_emprestimo: day, prazo: day)
    end
    assert_raises(ArgumentError) { catalog.emprestimos_atrasados("2026-11-03") }
    assert catalog.disponivel?(item.id)
    assert_empty catalog.emprestimos_ativos
  end

end
