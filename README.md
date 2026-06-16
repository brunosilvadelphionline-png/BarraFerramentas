# BarraFerramentas

Menu de bandeja do Windows para abrir utilitarios organizados em pastas.

## Uso

1. Instale as dependencias com `install.bat`.
2. Ajuste `config.ini`.
3. Inicie com `start.vbs`.

Pastas dentro de `Menu` viram submenus. Arquivos com extensoes configuradas em
`config.ini` viram itens clicaveis.

## Configuracao

As principais opcoes ficam em `config.ini`:

- `path`: pasta usada para montar o menu.
- `title`: texto do icone na bandeja.
- `extensions`: extensoes aceitas no menu.
- `show_extensions`: exibe ou oculta a extensao no nome do item.

## Arquivos locais

Alguns arquivos operacionais ficam fora do versionamento por seguranca, como
RDPs, executaveis, logs/licencas e configuracoes de conexao. Mantenha esses
arquivos apenas no ambiente local quando necessario.

