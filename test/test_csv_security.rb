# frozen_string_literal: true

require "minitest/autorun"
require "csv"
require "date"
require_relative "../lib/empresta_comunidade/gestao"

class CsvSecurityTest < Minitest::Test
  TODAY = Date.new(2026, 11, 11)

  def setup
    @app = EmprestaComunidade::Gestao.new(hoje: -> { TODAY })
    @app.cadastrar_participante("@planilha", "Pessoa ficticia")
    @app.cadastrar_participante("pessoa-normal", "Outro teste")
  end

  def test_formula_prefixes_are_escaped_only_in_export
    @app.cadastrar_item("=item1", "=1+1", categoria: "livro")
    @app.cadastrar_item("mais", "+SOMA(1;2)", categoria: "outro")
    @app.cadastrar_item("menos", "-42", categoria: "outro")
    @app.cadastrar_item("arroba", "@funcao", categoria: "outro")
    @app.emprestar("=item1", "@planilha")
    @app.emprestar("mais", "pessoa-normal")
    @app.emprestar("menos", "pessoa-normal")
    @app.emprestar("arroba", "pessoa-normal")

    original = @app.snapshot
    rows = CSV.parse(@app.exportar_csv, headers: true)
    assert_equal 4, rows.length
    assert_equal "'=item1", rows[0]["item_id"]
    assert_equal "'=1+1", rows[0]["nome"]
    assert_equal "'@planilha", rows[0]["participante_id"]
    assert_equal "'+SOMA(1;2)", rows[1]["nome"]
    assert_equal "'-42", rows[2]["nome"]
    assert_equal "'@funcao", rows[3]["nome"]
    assert_equal original, @app.snapshot
    assert_equal "=1+1", @app.itens.find { |item| item["id"] == "=item1" }["nome"]
  end

  def test_unicode_format_and_spaces_cannot_hide_formulas
    zwsp = "\u200B"
    nbsp = "\u00A0"
    @app.cadastrar_item("f1", "#{zwsp}=1+2", categoria: "outro")
    @app.cadastrar_item("f2", "#{nbsp}@funcao", categoria: "outro")
    @app.emprestar("f1", "@planilha")
    @app.emprestar("f2", "pessoa-normal")

    rows = CSV.parse(@app.exportar_csv, headers: true)
    assert_equal "'" + zwsp + "=1+2", rows[0]["nome"]
    assert_equal "'" + nbsp + "@funcao", rows[1]["nome"]
  end

  def test_safe_values_and_numeric_counters_are_preserved
    @app.cadastrar_item("livro", "Livro de matematica", categoria: "livro")
    @app.emprestar("livro", "pessoa-normal")
    row = CSV.parse(@app.exportar_csv, headers: true).first
    assert_equal "livro", row["item_id"]
    assert_equal "Livro de matematica", row["nome"]
    assert_equal "0", row["renovacoes"]
    assert_equal "2026-11-25", row["prazo"]
  end

  def test_empty_csv_retains_header
    table = CSV.parse(@app.exportar_csv, headers: true)
    assert_empty table
    assert_equal %w[item_id nome categoria participante_id retirada prazo renovacoes], table.headers
  end
end
