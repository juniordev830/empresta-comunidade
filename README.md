# Empresta Comunidade

Empréstimo de livros, ferramentas e equipamentos entre participantes.

## Estado atual

MVP executável em branch de desenvolvimento, com testes automatizados. Catálogo em memória com empréstimo e devolução de itens. Ainda não há usuários, API ou persistência.

## Tecnologias implementadas

Ruby 3.3 e Minitest.

## Escopo da primeira versão

- [ ] Cadastrar itens e participantes
- [ ] Registrar empréstimos e devoluções
- [ ] Consultar atrasos

## Critérios para concluir a primeira versão

- [ ] Implementar o fluxo principal com validação de entradas e tratamento de erros.
- [ ] Documentar instalação, configuração e execução com comandos reproduzíveis.
- [ ] Adicionar exemplos de uso e dados fictícios.
- [ ] Verificar os casos principais e limites e registrar os resultados.

## Desenvolvimento

Execute na raiz do repositório:

```bash
ruby -Ilib test/test_empresta_comunidade.rb
```

O GitHub Actions executa a validação em pushes e pull requests. Este é um núcleo demonstrativo; as funcionalidades ainda marcadas como pendentes na lista acima continuam planejadas.

## Privacidade e configuração

Usar dados fictícios nos exemplos e manter senhas, tokens, arquivos pessoais e credenciais fora do controle de versão.

## Licença

Ainda não definida.
