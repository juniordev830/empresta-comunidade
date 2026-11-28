# Engenharia reversa e estudo — Empresta Comunidade

## Objetivo e fluxo

Empréstimos de itens, devoluções e pendências. Compare as transições simples em Catalogo com as regras de participante, item e histórico na classe Gestao.

**Tecnologias identificadas** · Ruby.

**Revisão de referência** · `7730bdddbdf5`.

## Mapa do código

| Caminho | Papel de leitura | Símbolos selecionados |
| --- | --- | --- |
| [lib/empresta_comunidade.rb](../lib/empresta_comunidade.rb) | Implementação | `Catalogo`, `initialize`, `cadastrar`, `emprestar`, `devolver`, `disponivel`, `emprestimos_atrasados`, `emprestimos_ativos` |
| [lib/empresta_comunidade/gestao.rb](../lib/empresta_comunidade/gestao.rb) | Implementação | `EmprestaComunidade`, `Gestao`, `initialize`, `cadastrar_participante`, `participantes`, `cadastrar_item`, `itens`, `pesquisar`, `emprestar` |

## Configuração e referências

Referências existentes: [docs/GUIA_DE_VALIDACAO.md](GUIA_DE_VALIDACAO.md).

## Roteiro de estudo e desenvolvimento

1. Comece pelo fluxo descrito acima e localize seus pontos de entrada no mapa. Acompanhe uma entrada válida até a transformação ou a resposta.
2. Abra um teste relacionado ao fluxo e descreva qual regra ele protege. Compare o tratamento esperado para entradas válidas, inválidas e nos limites.
3. Ao adicionar uma regra, determine qual módulo controla o dado e cubra o caso nesse nível. Em seguida, confira o efeito no comando, na API ou na interface de entrada.

**Pergunta de entrevista**

Como impediria que o mesmo exemplar aparecesse emprestado a duas pessoas?

## Testes versionados

Arquivos para começar a leitura dos cenários de teste: [test/test_csv_security.rb](../test/test_csv_security.rb), [test/test_empresta_comunidade.rb](../test/test_empresta_comunidade.rb), [test/test_gestao.rb](../test/test_gestao.rb).

Os comandos e versões de runtime usados no CI ficam em [.github/workflows/ci.yml](../.github/workflows/ci.yml).

[Voltar ao README](../README.md).
