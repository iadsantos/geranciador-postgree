
## 🚀 Gerenciador de PostgreSQL - Versão Atualizada 🎉

Este script Bash é um gerenciador completo para o PostgreSQL, permitindo a instalação, gerenciamento de usuários, backup, restauração e diversas outras operações diretamente do terminal. 🖥️

### 🛠️ Funcionalidades Disponíveis

1. **📥 Instalar PostgreSQL**: Permite instalar a versão 15, a versão mais recente, ou atualizar do PostgreSQL 15 para o 16.
2. **👤 Criar um novo usuário**: Criação de um novo usuário no PostgreSQL com permissões especificadas.
3. **🗑️ Deletar usuário e banco de dados**: Remove o usuário selecionado e o banco de dados associado.
4. **📜 Listar todos os usuários**: Lista todos os usuários existentes no PostgreSQL.
5. **💾 Fazer backup do banco de dados**: Cria um backup do banco de dados especificado no formato compatível com `pg_restore`.
6. **🛡️ Restaurar banco de dados**: Restaura um banco de dados a partir de um arquivo de backup, com opção de realizar backup de segurança antes da restauração.
7. **📊 Ver tamanho dos bancos de dados**: Mostra o tamanho de todos os bancos de dados existentes.
8. **▶️ Iniciar PostgreSQL**: Inicia o serviço do PostgreSQL.
9. **⏹️ Parar PostgreSQL**: Para o serviço do PostgreSQL.
10. **🔄 Reiniciar PostgreSQL**: Reinicia o serviço do PostgreSQL.
11. **📡 Ver status do PostgreSQL**: Exibe o status atual do serviço do PostgreSQL.
12. **🧹 Desinstalar PostgreSQL e apagar tudo**: Desinstala completamente o PostgreSQL e apaga todos os dados relacionados.
13. **🚪 Sair**: Encerra o script.

### 📋 Instruções de Uso

1. **🔒 Permissões Necessárias**: O script deve ser executado como root para garantir o funcionamento correto das operações de instalação, gerenciamento e backups.
2. **⚙️ Execução**: O script original se chama `gerenciador.sh` e deve ser criado no diretório `/home`. Para executar o script, certifique-se de que ele é executável com o comando:
   ```bash
   chmod +x /home/gerenciador.sh
   ```
   Em seguida, rode o script com:
   ```bash
   sudo /home/gerenciador.sh
   ```
3. **🎯 Escolha de Opções**: Utilize o menu interativo para escolher as opções desejadas, respondendo conforme as instruções na tela.

### 📌 Requisitos

- 🐧 Sistema operacional Linux com suporte para Bash.
- 🌐 Conexão à internet para instalação de pacotes.
- 👑 Permissões de root para instalar, iniciar, parar, e gerenciar o PostgreSQL.

### 🚀 Melhorias na Versão Atual

- **🔐 Autenticação Flexível**: Ajuste de métodos de autenticação para evitar erros comuns de conexão.
- **🛡️ Backup com Segurança**: Implementação de backups automáticos de segurança antes da restauração de bancos de dados.
- **🧹 Desinstalação Completa**: Função aprimorada para remover completamente o PostgreSQL e seus dados.
- **📏 Gestão Avançada de Tamanho**: Visualização do tamanho dos bancos para um melhor gerenciamento de recursos.

### ⚠️ Observações

- **🚫 Executar Fora da Pasta /root**: O script recomenda a execução fora da pasta `/root` para evitar problemas de permissão e segurança.


### 👨‍💻 Autor e Manutenção

Este script foi desenvolvido por **Iadsantos** para auxiliar na administração de bancos de dados PostgreSQL, oferecendo uma interface amigável e recursos completos de gestão. 🌟


### 📦 Como Usar o Script

**Usando `curl`:**
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/iadsantos/geranciador-postgree/main/gerenciador.sh)"
```

**Usando `wget`:**
```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/iadsantos/geranciador-postgree/main/gerenciador.sh)"
```

### 🛠️ Clonar o Repositório e Executar

1. Clone este repositório:
   ```bash
   git clone https://github.com/iadsantos/geranciador-postgree.git
   cd gerenciador-postgree
   ```

2. Dê permissão de execução ao script:
   ```bash
   chmod +x gerenciador.sh
   ```

3. Execute o script:
   ```bash
   sudo ./gerenciador.sh
   ```
