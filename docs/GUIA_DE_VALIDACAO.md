# Desenvolvimento e validação — Empresta Comunidade

## Estado implementado

Biblioteca Ruby para empréstimos entre membros de uma comunidade; não há servidor ou interface.

## Estrutura relevante

`lib/empresta_comunidade.rb`, `test/test_empresta_comunidade.rb`.

## Como reproduzir verificações

`ruby -Ilib test/test_empresta_comunidade.rb`.

Os exemplos devem usar entradas fictícias. Registrar explicitamente o que foi de fato executado no ambiente e comparar com o CI.

## Regressão prioritária

Testar entrega e devolução repetida, empréstimo de item indisponível, datas inconsistentes e identificação de registros.

## Próximos limites a resolver

Não utilizar nomes reais de usuários em fixtures; definir política de retenção e de privacidade antes de criar cadastro.

## Revisão de contribuição

- [ ] Mudança melhora uma regra, teste ou integração real.
- [ ] Cenários de entrada, saída e erro estão documentados.
- [ ] Nada de dados pessoais, credenciais ou arquivos gerados versionados.
- [ ] PR separado antes de alterar a principal.
