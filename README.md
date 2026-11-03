# Empresta Comunidade

Catálogo em **Ruby 3.3** para emprestar livros, ferramentas e equipamentos, registrar responsáveis e controlar devoluções e atrasos.

## Funcionalidades

- `cadastrar(id, nome)` inclui um item único, rejeitando IDs repetidos mesmo durante empréstimos ativos.
- `emprestar(id)` e `devolver(item)` permanecem disponíveis para uso simples.
- `emprestar(id, pessoa:, data_emprestimo:, prazo:)` registra um empréstimo com nome de referência, data e prazo explícitos.
- `emprestimos_atrasados(hoje)` devolve os empréstimos cujo prazo é **anterior** ao dia consultado, em ordem de vencimento; o dia do prazo não conta como atraso.
- `emprestimos_ativos` fornece uma lista imutável para consultas. Não é possível devolver um item que não está emprestado nem forjar um item com o mesmo ID.

## Exemplo

```ruby
require "date"
require_relative "lib/empresta_comunidade"

catalogo = Catalogo.new
item = catalogo.cadastrar("furadeira-1", "Furadeira")
catalogo.emprestar(
  item.id,
  pessoa: "Participante fictício",
  data_emprestimo: Date.new(2026, 11, 3),
  prazo: Date.new(2026, 11, 10)
)
puts catalogo.emprestimos_atrasados(Date.new(2026, 11, 11)).map { |e| e.item.nome }
catalogo.devolver(item)
```

O empréstimo antigo sem dados de prazo continua funcionando, mas não pode aparecer na consulta de atrasos por não ter vencimento definido.

## Testes

```bash
ruby -Ilib test/test_empresta_comunidade.rb
```

A suíte Minitest cobre empréstimos, prazo, devolução, duplicidade, objetos inválidos e coleções imutáveis; o GitHub Actions executa os testes automaticamente.

## Limites

MVP em memória, de processo único, sem API, persistência, autenticação, cobrança ou notificações. Um nome no empréstimo não equivale a autenticação de participante; para produção é necessário acrescentar cadastro, autorização e proteção de dados. Os exemplos são fictícios e não devem conter informações reais de terceiros.

Licença: ainda não definida.
