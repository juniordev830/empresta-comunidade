# frozen_string_literal: true

require "csv"
require "date"
require "json"
require "tempfile"
require_relative "../empresta_comunidade"

module EmprestaComunidade
  # Camada de aplicação sobre o catálogo original. Não altera a API de Catalogo.
  # Todos os dados são locais; não há contas, rede nem serviços externos.
  class Gestao
    MAX_EMPRESTIMOS = 3
    MAX_RENOVACOES = 2
    PRAZO_PADRAO = 14
    CATEGORIAS = %w[livro ferramenta equipamento outro].freeze

    attr_reader :catalogo

    def initialize(catalogo: Catalogo.new, hoje: -> { Date.today })
      raise ArgumentError, "relógio inválido" unless hoje.respond_to?(:call)

      @catalogo = catalogo
      @hoje = hoje
      @participantes = {}
      @metadados = {}
      @ativos = {}
      @filas = Hash.new { |hash, key| hash[key] = [] }
      @historico = []
      @sequencia = 0
    end

    def cadastrar_participante(id, nome, contato: nil)
      id = texto_obrigatorio(id, "id")
      nome = texto_obrigatorio(nome, "nome")
      raise ArgumentError, "participante já cadastrado" if @participantes.key?(id)
      contato = texto_opcional(contato, "contato")

      @participantes[id] = { "id" => id, "nome" => nome, "contato" => contato }
      registrar("participante_cadastrado", participante_id: id)
      copia(@participantes.fetch(id))
    end

    def participantes
      @participantes.values.sort_by { |p| p.fetch("id") }.map { |p| copia(p) }
    end

    def cadastrar_item(id, nome, categoria: "outro", descricao: nil)
      id = texto_obrigatorio(id, "id")
      nome = texto_obrigatorio(nome, "nome")
      categoria = texto_obrigatorio(categoria, "categoria").downcase
      raise ArgumentError, "categoria inválida" unless CATEGORIAS.include?(categoria)
      descricao = texto_opcional(descricao, "descrição")

      item = @catalogo.cadastrar(id, nome)
      @metadados[id] = {
        "id" => item.id, "nome" => item.nome,
        "categoria" => categoria, "descricao" => descricao
      }
      registrar("item_cadastrado", item_id: id)
      copia(@metadados.fetch(id))
    end

    def itens
      @metadados.keys.sort.map { |id| apresentar_item(id) }
    end

    def pesquisar(termo: nil, categoria: nil, disponivel: nil)
      if categoria
        categoria = texto_obrigatorio(categoria, "categoria").downcase
        raise ArgumentError, "categoria inválida" unless CATEGORIAS.include?(categoria)
      end
      unless disponivel.nil? || disponivel == true || disponivel == false
        raise ArgumentError, "disponivel deve ser booleano"
      end
      termo = texto_opcional(termo, "termo")&.downcase

      itens.select do |item|
        categoria_ok = categoria.nil? || item.fetch("categoria") == categoria
        disponibilidade_ok = disponivel.nil? || item.fetch("disponivel") == disponivel
        texto = [item.fetch("id"), item.fetch("nome"), item["descricao"]].compact.join(" ").downcase
        categoria_ok && disponibilidade_ok && (termo.nil? || texto.include?(termo))
      end
    end

    def emprestar(item_id, participante_id, dias: PRAZO_PADRAO, data: hoje)
      item_id = texto_obrigatorio(item_id, "item")
      participante_id = texto_obrigatorio(participante_id, "participante")
      participante = participante!(participante_id)
      item!(item_id)
      data = data_valida(data)
      dias = dias_validos(dias)
      raise ArgumentError, "item indisponível" unless @catalogo.disponivel?(item_id)
      raise ArgumentError, "limite de empréstimos atingido" if emprestimos_de(participante_id).length >= MAX_EMPRESTIMOS

      fila = @filas.fetch(item_id, [])
      if !fila.empty? && fila.first != participante_id
        raise ArgumentError, "item reservado para outra pessoa"
      end

      @catalogo.emprestar(
        item_id, pessoa: participante.fetch("nome"),
        data_emprestimo: data, prazo: data + dias
      )
      fila.shift if fila.first == participante_id
      @ativos[item_id] = {
        "item_id" => item_id, "participante_id" => participante_id,
        "retirada" => data.iso8601, "prazo" => (data + dias).iso8601,
        "renovacoes" => 0
      }
      registrar("emprestado", item_id: item_id, participante_id: participante_id, data: data)
      copia(@ativos.fetch(item_id))
    end

    def devolver(item_id, data: hoje)
      item_id = texto_obrigatorio(item_id, "item")
      data = data_valida(data)
      emprestimo = @ativos.fetch(item_id) { raise ArgumentError, "item não emprestado" }
      if data < Date.iso8601(emprestimo.fetch("retirada"))
        raise ArgumentError, "devolução anterior à retirada"
      end

      registro = @catalogo.emprestimos_ativos.find { |loan| loan.item.id == item_id }
      raise ArgumentError, "catálogo inconsistente" unless registro

      @catalogo.devolver(registro.item)
      @ativos.delete(item_id)
      registrar("devolvido", item_id: item_id, participante_id: emprestimo.fetch("participante_id"), data: data)
      copia(emprestimo).merge("devolucao" => data.iso8601)
    end

    def renovar(item_id, participante_id, dias: 7, data: hoje)
      item_id = texto_obrigatorio(item_id, "item")
      participante_id = texto_obrigatorio(participante_id, "participante")
      data = data_valida(data)
      dias = dias_validos(dias)
      emprestimo = @ativos.fetch(item_id) { raise ArgumentError, "item não emprestado" }
      raise ArgumentError, "empréstimo de outra pessoa" unless emprestimo.fetch("participante_id") == participante_id
      raise ArgumentError, "limite de renovações" if emprestimo.fetch("renovacoes") >= MAX_RENOVACOES
      raise ArgumentError, "há reservas pendentes" unless @filas.fetch(item_id, []).empty?
      raise ArgumentError, "empréstimo vencido" if Date.iso8601(emprestimo.fetch("prazo")) < data
      raise ArgumentError, "data anterior à retirada" if data < Date.iso8601(emprestimo.fetch("retirada"))

      # O catálogo legado não expõe renovação. Recria o empréstimo somente
      # após todas as validações, preservando o identificador e a pessoa.
      registro = @catalogo.emprestimos_ativos.find { |loan| loan.item.id == item_id }
      raise ArgumentError, "catálogo inconsistente" unless registro
      novo_prazo = Date.iso8601(emprestimo.fetch("prazo")) + dias
      @catalogo.devolver(registro.item)
      @catalogo.emprestar(
        item_id, pessoa: participante!(participante_id).fetch("nome"),
        data_emprestimo: Date.iso8601(emprestimo.fetch("retirada")),
        prazo: novo_prazo
      )
      emprestimo["prazo"] = novo_prazo.iso8601
      emprestimo["renovacoes"] += 1
      registrar("renovado", item_id: item_id, participante_id: participante_id, data: data)
      copia(emprestimo)
    end

    def reservar(item_id, participante_id)
      item_id = texto_obrigatorio(item_id, "item")
      participante_id = texto_obrigatorio(participante_id, "participante")
      item!(item_id)
      participante!(participante_id)
      raise ArgumentError, "item está disponível" if @catalogo.disponivel?(item_id)
      raise ArgumentError, "você já possui o item" if @ativos.fetch(item_id)["participante_id"] == participante_id

      fila = @filas[item_id]
      raise ArgumentError, "reserva duplicada" if fila.include?(participante_id)
      fila << participante_id
      registrar("reservado", item_id: item_id, participante_id: participante_id)
      fila.dup
    end

    def cancelar_reserva(item_id, participante_id)
      item_id = texto_obrigatorio(item_id, "item")
      participante_id = texto_obrigatorio(participante_id, "participante")
      fila = @filas.fetch(item_id, [])
      raise ArgumentError, "reserva inexistente" unless fila.delete(participante_id)

      registrar("reserva_cancelada", item_id: item_id, participante_id: participante_id)
      fila.dup
    end

    def lista_espera(item_id)
      item!(texto_obrigatorio(item_id, "item"))
      @filas.fetch(item_id, []).dup
    end

    def emprestimos_de(participante_id)
      participante!(texto_obrigatorio(participante_id, "participante"))
      @ativos.values.select { |e| e.fetch("participante_id") == participante_id }
             .sort_by { |e| e.fetch("prazo") }.map { |e| copia(e) }
    end

    def emprestimos_ativos
      @ativos.values.sort_by { |e| [e.fetch("prazo"), e.fetch("item_id")] }.map { |e| copia(e) }
    end

    def atrasados(data: hoje)
      data = data_valida(data)
      emprestimos_ativos.select { |e| Date.iso8601(e.fetch("prazo")) < data }
                        .map { |e| e.merge("dias_atraso" => (data - Date.iso8601(e.fetch("prazo"))).to_i) }
    end

    def historico(tipo: nil, item_id: nil, participante_id: nil)
      eventos = @historico
      eventos = eventos.select { |e| e.fetch("tipo") == tipo } if tipo
      eventos = eventos.select { |e| e["item_id"] == item_id } if item_id
      eventos = eventos.select { |e| e["participante_id"] == participante_id } if participante_id
      eventos.map { |e| copia(e) }
    end

    def estatisticas(data: hoje)
      data = data_valida(data)
      {
        "participantes" => @participantes.size,
        "itens" => @metadados.size,
        "disponiveis" => @metadados.keys.count { |id| @catalogo.disponivel?(id) },
        "emprestados" => @ativos.size,
        "atrasados" => atrasados(data: data).size,
        "reservas" => @filas.values.sum(&:size),
        "eventos" => @historico.size
      }
    end

    def exportar_csv
      CSV.generate(headers: true) do |csv|
        csv << %w[item_id nome categoria participante_id retirada prazo renovacoes]
        emprestimos_ativos.each do |loan|
          item = @metadados.fetch(loan.fetch("item_id"))
          row = [loan.fetch("item_id"), item.fetch("nome"), item.fetch("categoria"),
                 loan.fetch("participante_id"), loan.fetch("retirada"),
                 loan.fetch("prazo"), loan.fetch("renovacoes")]
          csv << row.map { |value| csv_safe_cell(value) }
        end
      end
    end

    def snapshot
      {
        "versao" => 1,
        "participantes" => participantes,
        "itens" => @metadados.keys.sort.map { |id| copia(@metadados.fetch(id)) },
        "ativos" => emprestimos_ativos,
        "filas" => @filas.reject { |_id, fila| fila.empty? }.transform_values(&:dup),
        "historico" => historico
      }
    end

    def salvar(caminho)
      caminho = texto_obrigatorio(caminho, "caminho")
      diretorio = File.dirname(File.expand_path(caminho))
      Tempfile.create(["empresta-", ".json"], diretorio) do |arquivo|
        arquivo.write(JSON.pretty_generate(snapshot))
        arquivo.flush
        arquivo.fsync
        File.rename(arquivo.path, caminho)
      end
      caminho
    end

    def self.carregar(caminho, hoje: -> { Date.today })
      dados = JSON.parse(File.read(caminho))
      raise ArgumentError, "formato de dados inválido" unless dados.is_a?(Hash) && dados["versao"] == 1
      %w[participantes itens ativos historico].each do |chave|
        raise ArgumentError, "campo inválido: #{chave}" unless dados[chave].is_a?(Array)
      end
      raise ArgumentError, "filas inválidas" unless dados["filas"].is_a?(Hash)

      gestao = new(hoje: hoje)
      dados.fetch("participantes").each do |p|
        gestao.cadastrar_participante(p.fetch("id"), p.fetch("nome"), contato: p["contato"])
      end
      dados.fetch("itens").each do |i|
        gestao.cadastrar_item(i.fetch("id"), i.fetch("nome"), categoria: i.fetch("categoria"),
                             descricao: i["descricao"])
      end
      dados.fetch("ativos").each do |loan|
        inicio = Date.iso8601(loan.fetch("retirada"))
        prazo = Date.iso8601(loan.fetch("prazo"))
        raise ArgumentError, "prazo inválido" if prazo < inicio
        item_id = loan.fetch("item_id")
        participante_id = loan.fetch("participante_id")
        renovacoes = loan.fetch("renovacoes")
        raise ArgumentError, "renovações inválidas" unless renovacoes.is_a?(Integer) && renovacoes.between?(0, MAX_RENOVACOES)
        raise ArgumentError, "prazo excessivo" unless (prazo - inicio).to_i.between?(1, 270)
        raise ArgumentError, "empréstimo duplicado" if gestao.instance_variable_get(:@ativos).key?(item_id)
        gestao.send(:item!, item_id)
        participante = gestao.send(:participante!, participante_id)
        gestao.catalogo.emprestar(item_id, pessoa: participante.fetch("nome"),
                                 data_emprestimo: inicio, prazo: prazo)
        gestao.instance_variable_get(:@ativos)[item_id] = {
          "item_id" => item_id, "participante_id" => participante_id,
          "retirada" => inicio.iso8601, "prazo" => prazo.iso8601,
          "renovacoes" => renovacoes
        }
      end
      dados.fetch("filas").each do |item_id, fila|
        raise ArgumentError, "fila inválida" unless fila.is_a?(Array) && fila.uniq == fila
        fila.each do |participante_id|
          gestao.reservar(item_id, participante_id)
        end
      end
      eventos = dados.fetch("historico")
      unless eventos.all? { |e| e.is_a?(Hash) && e["sequencia"].is_a?(Integer) && e["tipo"].is_a?(String) } &&
             eventos.map { |e| e["sequencia"] } == (1..eventos.length).to_a
        raise ArgumentError, "histórico inválido"
      end
      gestao.instance_variable_set(:@historico, gestao.send(:copia, eventos))
      gestao.instance_variable_set(:@sequencia, eventos.length)
      gestao
    rescue KeyError, Date::Error, JSON::ParserError, TypeError => e
      raise ArgumentError, "arquivo de dados inválido: #{e.message}"
    end

    private

    # CSV quoting alone does not prevent formulas from executing in spreadsheet
    # software. Preserve raw JSON records and only escape risky CSV text cells.
    def csv_safe_cell(value)
      return value unless value.is_a?(String)

      value.match?(/\A[\s\p{Z}\p{Cf}]*[=+\-@]/u) ? "'" + value : value
    end

    def hoje
      data_valida(@hoje.call)
    end

    def texto_obrigatorio(valor, campo)
      raise ArgumentError, "#{campo} obrigatório" unless valor.is_a?(String) && !valor.strip.empty?
      raise ArgumentError, "#{campo} muito longo" if valor.strip.length > 200
      valor.strip
    end

    def texto_opcional(valor, campo)
      return nil if valor.nil?
      texto_obrigatorio(valor, campo)
    end

    def data_valida(valor)
      raise ArgumentError, "data deve ser Date" unless valor.instance_of?(Date)
      valor
    end

    def dias_validos(valor)
      raise ArgumentError, "dias devem estar entre 1 e 90" unless valor.is_a?(Integer) && valor.between?(1, 90)
      valor
    end

    def participante!(id)
      @participantes.fetch(id) { raise ArgumentError, "participante não encontrado" }
    end

    def item!(id)
      @metadados.fetch(id) { raise ArgumentError, "item não encontrado" }
    end

    def apresentar_item(id)
      copia(@metadados.fetch(id)).merge(
        "disponivel" => @catalogo.disponivel?(id),
        "reservas" => @filas.fetch(id, []).length
      )
    end

    def registrar(tipo, item_id: nil, participante_id: nil, data: nil)
      @sequencia += 1
      @historico << {
        "sequencia" => @sequencia, "tipo" => tipo,
        "item_id" => item_id, "participante_id" => participante_id,
        "data" => data&.iso8601
      }
    end

    def copia(valor)
      JSON.parse(JSON.generate(valor))
    end
  end
end
