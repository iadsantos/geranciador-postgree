
# 🛠️ PostgreSQL Manager Script

Bem-vindo ao **PostgreSQL Manager Script**, a sua ferramenta poderosa e simplificada para gerenciar usuários, bancos de dados, backups e restaurações no PostgreSQL! Este script em Shell é a solução ideal para quem busca automação e controle total sobre o seu ambiente de banco de dados. 🎉

## 🚀 Funcionalidades

1. **Listar todos os usuários** 👥
   - Lista todos os usuários cadastrados no PostgreSQL, ajudando você a ter uma visão geral de quem está na sua base.

2. **Criar um novo usuário e banco de dados** 🆕
   - Permite criar um novo usuário e associar um banco de dados a ele, configurando permissões automaticamente. Seguro, rápido e fácil de usar!

3. **Restaurar banco de dados a partir de um arquivo SQL** ♻️
   - Restaure o conteúdo de um banco de dados com segurança, com backup automático antes da restauração. Não perca dados importantes!

4. **Fazer backup do banco de dados** 💾
   - Realize backups completos dos seus bancos de dados, definindo o caminho de destino e garantindo que seus dados estejam sempre seguros.

5. **Deletar usuário e banco de dados** ❌
   - Remove um usuário do PostgreSQL junto com o banco de dados associado. O script cuida de desconectar usuários e revogar permissões antes da exclusão, garantindo um processo limpo e seguro.

6. **Sair** 🚪
   - Encerra o script de maneira elegante.

## 📖 Como Usar

### 1. Listar todos os usuários
Selecione a opção 1 para visualizar todos os usuários registrados no PostgreSQL. Ideal para verificar quem está ativo e com quais permissões.

```bash
1. Listar todos os usuários
```

### 2. Criar um novo usuário e banco de dados
Esta opção permite criar um novo usuário, solicitar o nome do banco de dados a ser criado e definir uma senha. Todos os detalhes de configuração são ajustados automaticamente pelo script.

```bash
2. Criar um novo usuário
```

### 3. Restaurar banco de dados a partir de um arquivo SQL
Restaure seu banco de dados de maneira segura! Basta informar o nome do banco e o caminho do arquivo SQL. O script cuidará do resto, incluindo um backup de segurança antes da restauração.

```bash
3. Restaurar banco de dados
```

### 4. Fazer backup do banco de dados
Garanta que seus dados estejam sempre seguros com backups regulares. Informe o banco de dados que deseja fazer backup e o diretório de destino. 

```bash
4. Fazer backup do banco de dados
```

### 5. Deletar usuário e banco de dados
Com a opção 5, você pode remover um usuário e seu banco de dados associado. O script revoga todas as permissões e desconecta os usuários ativos antes da exclusão, prevenindo erros e conflitos.

```bash
5. Deletar usuário e banco de dados
```

### 6. Sair
Quando terminar, escolha a opção 6 para sair do gerenciador.

```bash
6. Sair
```

## ⚙️ Requisitos

- **PostgreSQL**: Certifique-se de que o PostgreSQL está instalado e configurado no seu sistema.
- **Permissões**: Execute o script com permissões adequadas para modificar usuários e bancos de dados (normalmente com `sudo`).

## 📋 Notas de Segurança

- Este script é projetado para ser executado em um ambiente controlado. 
- **Senhas não são armazenadas permanentemente**, garantindo que seu ambiente de banco de dados permaneça seguro.
- Certifique-se de ter backups regulares dos seus dados e de entender o impacto das operações de exclusão.

## 📞 Suporte

Se precisar de ajuda ou tiver sugestões para melhorar esta ferramenta, não hesite em entrar em contato! 💬
