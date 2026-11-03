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
end
