# Empresta Comunidade

Aplicação local em Ruby para organizar o empréstimo comunitário de livros,
ferramentas e equipamentos. **Sem servidor, contas externas ou dependências de produção.**

## Recursos implementados

- Catálogo legado `Catalogo` preservado (API `cadastrar`, `emprestar`, `devolver` e `disponivel?`).
- Participantes com identificador único, nome e contato opcional.
- Itens categorizados, descrições e busca por texto/disponibilidade.
- Empréstimos com prazo configurável (1 a 90 dias), limite de três por participante.
- Atrasos calculados por dia, sem considerar o próprio vencimento como atraso.
- Renovações limitadas a duas, bloqueadas após o vencimento ou diante de reservas.
- Lista de espera FIFO, cancelamento e prioridade de quem reservou primeiro.
- Histórico auditável, indicadores operacionais e exportação CSV.
- Persistência JSON local com escrita por arquivo temporário e restauração validada.

## Requisitos e testes

Ruby 3.3, biblioteca padrão (Minitest, CSV, JSON, Date e Tempfile).
Não é necessário instalar gems adicionais.

```sh
ruby -Ilib -Itest -e 'Dir["test/test_*.rb"].sort.each { |file| require_relative file }'
```

O GitHub Actions executa verificação de sintaxe e toda a suíte de testes a cada push e PR.

## Exemplo completo

```ruby
require "date"
require_relative "lib/empresta_comunidade/gestao"

gestao = EmprestaComunidade::Gestao.new
gestao.cadastrar_participante("ana", "Ana", contato: "ana@example.test")
gestao.cadastrar_participante("bia", "Bia")
gestao.cadastrar_item("furadeira", "Furadeira", categoria: "ferramenta")

gestao.emprestar("furadeira", "ana", dias: 7, data: Date.new(2026, 11, 8))
gestao.reservar("furadeira", "bia")
puts gestao.atrasados(data: Date.new(2026, 11, 16))
gestao.devolver("furadeira", data: Date.new(2026, 11, 16))
gestao.emprestar("furadeira", "bia", dias: 14, data: Date.new(2026, 11, 16))

puts gestao.exportar_csv
gestao.salvar("estado.json")
restaurado = EmprestaComunidade::Gestao.carregar("estado.json")
puts restaurado.estatisticas
```

## Contratos e regras

`Gestao` é uma camada opcional sobre o catálogo original. IDs são strings não vazias
de até 200 caracteres. Datas de operação são instâncias `Date`. O empréstimo
só pode ser feito se o item estiver disponível e, havendo fila, se o solicitante
for o primeiro. A devolução não permite data anterior à retirada. As consultas
retornam cópias dos registros, evitando mutações externas acidentais.

O JSON salvo contém dados dos participantes, catálogo, empréstimos, reservas
e eventos. **Não salve contatos reais em repositórios públicos.** Adicione
`estado.json` ao `.gitignore` de sua instalação ou armazene-o fora do repositório.
O sistema não implementa autenticação, sincronização multiusuário ou criptografia
dos arquivos locais. Para produção, planeje controle de acesso, backup e
persistência transacional.

## Evolução e compatibilidade

A API original de `Catalogo` continua utilizável sem `Gestao`. Esta branch
parte da implementação de prazos já desenvolvida em uma PR anterior, sem alterar
a `main`. O código de aplicação e os testes estão separados em
`lib/empresta_comunidade/gestao.rb` e `test/test_gestao.rb`.
