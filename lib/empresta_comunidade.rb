# frozen_string_literal: true

require "date"

Item = Struct.new(:id, :nome, keyword_init: true) unless defined?(Item)
Emprestimo = Struct.new(:item, :pessoa, :data_emprestimo, :prazo, keyword_init: true) unless defined?(Emprestimo)

class Catalogo
  def initialize
    @itens = {}
    @disponiveis = {}
    @emprestados = {}
  end

  def cadastrar(id, nome)
    raise ArgumentError, "id obrigatório" unless id.is_a?(String) && !id.strip.empty?
    raise ArgumentError, "nome obrigatório" unless nome.is_a?(String) && !nome.strip.empty?

    id = id.strip
    raise ArgumentError, "id já cadastrado" if @itens.key?(id)

    item = Item.new(id: id.freeze, nome: nome.strip.freeze).freeze
    @itens[id] = item
    @disponiveis[id] = item
    item
  end

  # Optional details preserve the old emprestar(id) API; without them no due date is set.
  def emprestar(id, pessoa: nil, data_emprestimo: nil, prazo: nil)
    item = @disponiveis[id]
    raise ArgumentError, "item indisponível" unless item

    details = [pessoa, data_emprestimo, prazo]
    if details.any?(&:nil?) && !details.all?(&:nil?)
      raise ArgumentError, "informe pessoa, data_emprestimo e prazo juntos"
    end
    unless details.all?(&:nil?)
      raise ArgumentError, "pessoa obrigatória" unless pessoa.is_a?(String) && !pessoa.strip.empty?
      unless data_emprestimo.instance_of?(Date) && prazo.instance_of?(Date) && prazo >= data_emprestimo
        raise ArgumentError, "datas de empréstimo inválidas"
      end
    end

    emprestimo = Emprestimo.new(
      item: item,
      pessoa: pessoa&.strip&.freeze,
      data_emprestimo: data_emprestimo,
      prazo: prazo
    ).freeze
    @disponiveis.delete(id)
    @emprestados[id] = emprestimo
    item
  end

  def devolver(item)
    unless item.is_a?(Item) && @itens[item.id].equal?(item) && @emprestados.key?(item.id)
      raise ArgumentError, "item não emprestado ou inválido"
    end
    @emprestados.delete(item.id)
    @disponiveis[item.id] = item
    item
  end

  def disponivel?(id)
    @disponiveis.key?(id)
  end

  def emprestimos_atrasados(hoje)
    raise ArgumentError, "data inválida" unless hoje.instance_of?(Date)

    @emprestados.values.select { |loan| loan.prazo && loan.prazo < hoje }
                .sort_by { |loan| [loan.prazo, loan.item.id] }.freeze
  end

  def emprestimos_ativos
    @emprestados.values.freeze
  end
end
