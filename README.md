
## Novidades da Versão 4 🚀

A versão 4 do Gerenciador PostgreSQL traz várias melhorias e novas funcionalidades para facilitar ainda mais a administração do seu banco de dados:

### 1. Detecção de Execução na Pasta `/root`
O script agora detecta quando é executado na pasta `/root` e oferece a opção de mover automaticamente para a pasta `/home` para evitar problemas de permissão.

### 2. Execução Automática na Nova Localização
Após mover o script, ele é executado automaticamente na nova localização, garantindo que o fluxo de trabalho não seja interrompido.

### 3. Backup de Segurança Opcional
Ao restaurar um banco de dados, o usuário pode optar por realizar um backup de segurança antes do processo de restauração.

### 4. Formato Atualizado de Backup
Os backups agora são salvos com o novo formato de data, facilitando a identificação: `nome_01_09_2023_01-01hr`.

Essas melhorias tornam o script mais robusto e adaptável, mantendo o foco na segurança e eficiência na gestão dos seus bancos de dados.

# Gerenciador PostgreSQL 🚀

Bem-vindo ao **Gerenciador PostgreSQL**! Este script é uma ferramenta poderosa e fácil de usar que ajuda você a gerenciar seu banco de dados PostgreSQL com facilidade e eficiência. Criado para desenvolvedores, DBAs e entusiastas, ele oferece uma interface interativa para realizar tarefas comuns com o PostgreSQL diretamente do terminal.

## Funcionalidades 🛠️

### 1. Instalar PostgreSQL
Instala a versão mais recente do PostgreSQL (15) no seu sistema. Se o PostgreSQL já estiver instalado, o script informará você, evitando instalações desnecessárias.

### 2. Iniciar PostgreSQL
Inicia o serviço do PostgreSQL, verificando primeiro se o serviço já está em execução para evitar redundâncias.

### 3. Parar PostgreSQL
Para o serviço do PostgreSQL, útil quando você precisa realizar manutenções ou ajustes no sistema.

### 4. Reiniciar PostgreSQL
Reinicia o serviço do PostgreSQL, ideal para aplicar novas configurações sem a necessidade de reiniciar o servidor.

### 5. Ver status do PostgreSQL
Exibe o status atual do serviço do PostgreSQL, mostrando se está ativo ou inativo, e outras informações detalhadas.

### 6. Listar todos os usuários
Lista todos os usuários cadastrados no PostgreSQL, permitindo que você visualize rapidamente quem tem acesso ao seu banco de dados.

### 7. Criar um novo usuário
Cria um novo usuário no PostgreSQL com um banco de dados atribuído. Você pode definir o nome do usuário, o banco de dados e a senha de forma segura.

### 8. Restaurar banco de dados
Restaura um banco de dados a partir de um arquivo SQL. Antes de restaurar, o script faz um backup de segurança, garantindo que seus dados estejam sempre protegidos.

### 9. Fazer backup do banco de dados
Realiza um backup completo do banco de dados especificado, salvando-o em um local seguro no servidor.

### 10. Deletar usuário e banco de dados
Remove um usuário e seu banco de dados associado, após confirmação, garantindo que apenas usuários autorizados realizem esta ação irreversível.

### 11. Sair
Fecha o gerenciador de forma segura.

## Como Usar 🚦

### Executar Diretamente do GitHub

Você pode executar o script diretamente do GitHub com os comandos abaixo:

**Usando `curl`:**
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/iadsantos/geranciador-postgree/main/gerenciador.sh)"
```

**Usando `wget`:**
```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/iadsantos/geranciador-postgree/main/gerenciador.sh)"
```

### Clonar o Repositório e Executar

1. Clone este repositório:
   ```bash
   git clone https://github.com/iadsantos/geranciador-postgree.git
   cd geranciador-postgree
   ```

2. Dê permissão de execução ao script:
   ```bash
   chmod +x gerenciador.sh
   ```

3. Execute o script:
   ```bash
   sudo ./gerenciador.sh
   ```

## Requisitos 📋

- Linux (Debian/Ubuntu)
- Acesso root para instalação e gerenciamento de serviços
- PostgreSQL 15 ou mais recente (pode ser instalado pelo script)

## Desenvolvedor 👨‍💻

Criado por **Iadsantos**, um desenvolvedor dedicado a criar soluções simples e eficientes para o gerenciamento de bancos de dados. Para saber mais sobre o trabalho dele, visite o GitHub: [Iadsantos](https://github.com/Iadsantos).

---

Divirta-se utilizando o Gerenciador PostgreSQL e torne seu gerenciamento de banco de dados muito mais fácil! Se você encontrar algum problema ou tiver sugestões de melhorias, fique à vontade para contribuir. 🚀
