# frozen_string_literal: true

Item = Struct.new(:id, :nome, keyword_init: true) unless defined?(Item)

class Catalogo
  def initialize
    @disponiveis = {}
  end

  def cadastrar(id, nome)
    raise ArgumentError, "nome obrigatório" if nome.to_s.strip.empty?
    @disponiveis[id] = Item.new(id: id, nome: nome.strip)
  end

  def emprestar(id)
    item = @disponiveis.delete(id)
    raise ArgumentError, "item indisponível" unless item
    item
  end

  def devolver(item)
    raise ArgumentError, "item inválido" unless item.is_a?(Item)
    @disponiveis[item.id] = item
  end

  def disponivel?(id)
    @disponiveis.key?(id)
  end
end
