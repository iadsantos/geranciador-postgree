#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root!"
    exit 1
fi

# Define a localização real do script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Verifica se o script está sendo executado na pasta /root
if [ "$SCRIPT_DIR" == "/root" ]; then
    echo "Aviso: Este script está sendo executado na pasta /root."
    read -p "Deseja mover o script para a pasta /home e executá-lo de lá? (s/n): " resposta

    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        # Define o caminho de destino na pasta /home com o nome correto do script
        destino="/home/$(basename "$0")"
        echo "Movendo o script para $destino..."
        cp "$0" "$destino"  # Faz uma cópia do script para o destino correto
        chmod +x "$destino"  # Garante que o script seja executável

        echo "Executando o script a partir de /home..."
        exec "$destino"  # Executa o script a partir da nova localização
        exit 0
    else
        echo "Finalizando o script."
        exit 1
    fi
fi

# Verifica se o script está sendo executado na pasta /home e, se sim, continua sem mostrar mensagens
if [[ "$SCRIPT_DIR" == "/home" ]]; then
    echo "Script já está sendo executado na pasta /home. Continuando a execução..."
fi

# Define o diretório de trabalho para /home se o script estiver sendo executado de outro lugar
WORK_DIR="/home"
cd "$WORK_DIR" || exit

# Função para instalar ou atualizar o PostgreSQL
instalar_postgresql() {
    echo "Escolha a versão do PostgreSQL para instalar ou atualizar:"
    echo "1. Instalar PostgreSQL 15"
    echo "2. Instalar a versão mais recente do PostgreSQL"
    echo "3. Atualizar do PostgreSQL 15 para o 16"
    read -p "Digite a opção desejada (1, 2 ou 3): " opcao

    case $opcao in
        1)
            if dpkg -l | grep -qw postgresql-15; then
                echo "PostgreSQL 15 já está instalado."
                return
            fi

            echo "Instalando PostgreSQL 15..."
            sudo apt-get install gnupg -y
            sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
            sudo apt-get update -y && sudo apt-get -y install postgresql-15
            ;;
        2)
            echo "Instalando a versão mais recente do PostgreSQL..."
            sudo apt-get install gnupg -y
            sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
            sudo apt-get update -y && sudo apt-get -y install postgresql
            ;;
        3)
            if dpkg -l | grep -qw postgresql-15; then
                echo "Atualizando do PostgreSQL 15 para o 16..."
                sudo apt-get install gnupg -y
                sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
                wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
                sudo apt-get update -y && sudo apt-get -y install postgresql-16
                echo "Atualização para o PostgreSQL 16 concluída com sucesso!"
            else
                echo "PostgreSQL 15 não está instalado, atualização não pode ser realizada."
            fi
            ;;
        *)
            echo "Opção inválida. Abortando a instalação."
            return
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "PostgreSQL instalado ou atualizado com sucesso!"
        sudo systemctl restart postgresql
    else
        echo "Erro ao instalar ou atualizar o PostgreSQL."
    fi
}

# Função para iniciar o serviço PostgreSQL
iniciar_postgresql() {
    if systemctl is-active --quiet postgresql; then
        echo "PostgreSQL já está em execução."
    else
        sudo systemctl start postgresql
        if systemctl is-active --quiet postgresql; then
            echo "Serviço PostgreSQL iniciado com sucesso."
        else
            echo "Erro ao iniciar o serviço PostgreSQL."
        fi
    fi
}

# Função para parar o serviço PostgreSQL
parar_postgresql() {
    sudo systemctl stop postgresql
    echo "Serviço PostgreSQL parado."
}

# Função para reiniciar o serviço PostgreSQL
reiniciar_postgresql() {
    sudo systemctl restart postgresql
    echo "Serviço PostgreSQL reiniciado."
}

# Função para verificar o status do serviço PostgreSQL
status_postgresql() {
    sudo systemctl status postgresql
}

# Função para verificar se um banco de dados existe
banco_existe() {
    local nome_banco="$1"
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$nome_banco"; then
        return 0
    else
        return 1
    fi
}

# Função para verificar se o banco de dados está vazio
banco_vazio() {
    local nome_banco="$1"
    local tabela_existe=$(sudo -u postgres psql -t -A -d "$nome_banco" -c \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1);")

    local possui_dados=$(sudo -u postgres psql -t -A -d "$nome_banco" -c \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables 
     WHERE table_schema = 'public' 
     AND (SELECT COUNT(*) FROM information_schema.tables 
          WHERE table_schema = 'public') > 0 LIMIT 1);")

    if [[ "$tabela_existe" == "t" && "$possui_dados" == "t" ]]; then
        return 1  # Banco NÃO está vazio
    else
        return 0  # Banco ESTÁ vazio
    fi
}

# Função para remover caracteres especiais de um nome, permitindo apenas letras e números
sanitizar_nome() {
    local nome="$1"
    nome=$(echo "$nome" | tr -cd '[:alnum:]')
    echo "$nome"
}

# Função para validar o nome do usuário e banco (somente letras e números)
validar_nome() {
    local nome="$1"
    if [[ "$nome" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0
    else
        echo "Erro: O nome '$nome' contém caracteres inválidos. Use apenas letras e números."
        return 1
    fi
}

# Função para criar um backup do banco de dados no formato compatível com pg_restore
fazer_backup() {
    # Lista os bancos de dados disponíveis, excluindo templates e o banco de sistema
    bancos=($(sudo -u postgres psql -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname <> 'postgres';"))

    if [ ${#bancos[@]} -eq 0 ]; then
        echo "Nenhum banco de dados disponível para backup."
        return
    fi

    echo "Bancos de dados disponíveis para backup:"
    for i in "${!bancos[@]}"; do
        echo "$((i+1)). ${bancos[$i]}"
    done

    while true; do
        read -p "Digite o número do banco de dados que deseja fazer backup: " escolha
        if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le "${#bancos[@]}" ]; then
            nome_banco="${bancos[$((escolha-1))]}"
            break
        else
            echo "Escolha inválida. Por favor, insira um número válido."
        fi
    done

    caminho_backup="$WORK_DIR/backups"

    # Verifica se o diretório de backups existe. Se não, cria e ajusta as permissões.
    if [ ! -d "$caminho_backup" ]; then
        echo "Diretório $caminho_backup não existe. Criando..."
        mkdir -p "$caminho_backup"

        # Verifique se o diretório foi criado com sucesso
        if [ $? -eq 0 ]; then
            echo "Diretório criado com sucesso."
        else
            echo "Erro ao criar o diretório $caminho_backup."
            exit 1  # Encerra o script em caso de erro ao criar o diretório
        fi

        # Assegura permissões 777 com sudo, para maior segurança
        echo "Alterando permissões do diretório $caminho_backup para 777..."
        chmod 777 "$caminho_backup"

        # Verifique se a permissão foi aplicada
        if [ $? -eq 0 ]; then
            echo "Permissões 777 aplicadas com sucesso!"
        else
            echo "Erro ao alterar permissões do diretório $caminho_backup."
            exit 1  # Encerra o script em caso de erro ao alterar permissões
        fi
    else
        # Verifica se as permissões do diretório estão corretas (777)
        permissoes=$(stat -c %a "$caminho_backup")
        if [ "$permissoes" != "777" ]; then
            echo "As permissões do diretório $caminho_backup não são 777. Ajustando..."
            sudo chmod 777 "$caminho_backup"
            if [ $? -eq 0 ]; then
                echo "Permissões 777 aplicadas com sucesso!"
            else
                echo "Erro ao alterar permissões do diretório $caminho_backup."
                exit 1  # Encerra o script em caso de erro ao alterar permissões
            fi
        fi
    fi

    # Define o nome do arquivo de backup com o formato desejado
    arquivo_backup="$caminho_backup/${nome_banco}_$(date +%d_%m_%Y_%H-%Mhr).backup"

    echo "Fazendo backup do banco de dados $nome_banco para o arquivo $arquivo_backup..."
    sudo -u postgres pg_dump -Fc -f "$arquivo_backup" "$nome_banco"

    if [ $? -eq 0 ]; then
        echo "Backup concluído com sucesso em $arquivo_backup!"
    else
        echo "Erro ao fazer o backup do banco de dados $nome_banco."
    fi
}

# Função para criar um backup de segurança do banco de dados antes de restaurar
backup_seguranca() {
    local nome_banco="$1"
    local caminho_backup="$WORK_DIR/backups/seguranca"

    if banco_vazio "$nome_banco"; then
        echo "O banco de dados $nome_banco está vazio. Nenhum backup de segurança necessário."
        return
    fi

    if [ ! -d "$caminho_backup" ]; then
        echo "Criando o diretório de backup de segurança em $caminho_backup..."
        mkdir -p "$caminho_backup"
        chmod 777 "$caminho_backup"
    fi

    # Define o nome do arquivo de backup de segurança com o formato desejado
    local arquivo_backup="$caminho_backup/${nome_banco}_backup_seguranca_$(date +%d_%m_%Y_%H-%Mhr).backup"

    echo "Criando backup de segurança do banco de dados $nome_banco para o arquivo $arquivo_backup..."
    sudo -u postgres pg_dump -Fc -f "$arquivo_backup" "$nome_banco"

    if [ $? -eq 0 ]; then
        echo "Backup de segurança concluído com sucesso em $arquivo_backup!"
    else
        echo "Erro ao criar o backup de segurança do banco de dados $nome_banco."
    fi
}

# Função para restaurar um banco de dados a partir de um arquivo de backup
restaurar_banco() {
    # Lista os bancos de dados disponíveis, excluindo templates e o banco de sistema
    bancos=($(sudo -u postgres psql -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname <> 'postgres';"))

    if [ ${#bancos[@]} -eq 0 ]; then
        echo "Nenhum banco de dados disponível para restauração."
        return
    fi

    echo "Bancos de dados disponíveis para restauração:"
    for i in "${!bancos[@]}"; do
        echo "$((i+1)). ${bancos[$i]}"
    done

    while true; do
        read -p "Digite o número do banco de dados que deseja restaurar: " escolha
        if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le "${#bancos[@]}" ]; then
            nome_banco="${bancos[$((escolha-1))]}"
            break
        else
            echo "Escolha inválida. Por favor, insira um número válido."
        fi
    done

    read -p "Digite o nome do arquivo de backup (ex: backup.backup): " arquivo_backup

    if [[ "$arquivo_backup" != /* ]]; then
        arquivo_backup="$WORK_DIR/backups/$arquivo_backup"
    fi

    if [ -f "$arquivo_backup" ]; then
        echo "Arquivo de backup encontrado: $arquivo_backup"
        
        # Pergunta ao usuário se deseja realizar o backup de segurança antes de restaurar
        read -p "Deseja realizar um backup de segurança antes de restaurar o banco de dados? (s/n): " escolha_backup

        if [[ "$escolha_backup" =~ ^[Ss]$ ]]; then
            backup_seguranca "$nome_banco"
        fi

        echo "Restaurando o banco de dados $nome_banco a partir do arquivo $arquivo_backup..."
        sudo -u postgres pg_restore -U postgres -d "$nome_banco" -v --clean --if-exists "$arquivo_backup"
        echo "Restauração concluída com sucesso!"
    else
        echo "Erro: Arquivo $arquivo_backup não encontrado!"
    fi
}

# Função para listar todos os usuários do PostgreSQL
listar_usuarios() {
    echo "Listando todos os usuários do PostgreSQL:"
    sudo -u postgres psql -c "\du"
}

# Função para criar um novo usuário do PostgreSQL
criar_usuario() {
    while true; do
        read -p "Digite o nome do usuário a ser criado: " nome_usuario
        if [[ -z "$nome_usuario" ]] || ! validar_nome "$nome_usuario"; then
            echo "Erro: O nome do usuário deve conter apenas letras e números e não pode estar vazio."
        else
            break
        fi
    done

    while true; do
        read -p "Digite o nome do banco de dados: " nome_banco
        if [[ -z "$nome_banco" ]] || ! validar_nome "$nome_banco"; then
            echo "Erro: O nome do banco de dados deve conter apenas letras e números e não pode estar vazio."
        else
            break
        fi
    done

    while true; do
        read -s -p "Digite a senha para o usuário: " senha
        echo
        if [[ -z "$senha" ]]; then
            echo "Erro: A senha não pode estar vazia."
        else
            break
        fi
    done

    echo "Criando usuário e banco de dados..."
    sudo -u postgres psql -c "CREATE USER $nome_usuario WITH PASSWORD '$senha' SUPERUSER CREATEDB CREATEROLE;"
    sudo -u postgres psql -c "CREATE DATABASE $nome_banco OWNER $nome_usuario;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $nome_banco TO $nome_usuario;"

    echo "Usuário $nome_usuario criado com sucesso, com permissões atribuídas, e banco $nome_banco configurado!"
}

# Função para deletar um usuário, banco e suas permissões
deletar_usuario() {
    echo "Listando todos os usuários do PostgreSQL:"
    usuarios=($(sudo -u postgres psql -c "\du" | awk '{print $1}' | grep -vE "Role|postgres|---------"))

    if [ ${#usuarios[@]} -eq 0 ]; then
        echo "Nenhum usuário disponível para deletar."
        return
    fi

    echo "Selecione um usuário para deletar (ou digite 0 para voltar ao menu):"
    echo "0. Voltar ao menu"
    for i in "${!usuarios[@]}"; do
        echo "$((i+1)). ${usuarios[$i]}"
    done

    read -p "Escolha o número do usuário: " escolha

    if [[ "$escolha" == "0" ]]; then
        echo "Voltando ao menu principal..."
        return
    fi

    if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -gt 0 ] && [ "$escolha" -le "${#usuarios[@]}" ]; then
        nome_usuario="${usuarios[$((escolha-1))]}"
        read -p "Tem certeza que deseja deletar o usuário $nome_usuario e seu banco associado? (s/n): " confirmacao
        if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
            banco_usuario=$(sudo -u postgres psql -At -c "SELECT datname FROM pg_database WHERE datname = '$nome_usuario';")

            if [ -n "$banco_usuario" ]; then
                sudo -u postgres psql -c "DROP DATABASE IF EXISTS $banco_usuario;"
            fi
            
            sudo -u postgres psql -c "REASSIGN OWNED BY $nome_usuario TO postgres;"
            sudo -u postgres psql -c "DROP OWNED BY $nome_usuario;"
            sudo -u postgres psql -c "DROP USER IF EXISTS $nome_usuario;"
            
            if sudo -u postgres psql -c "\du" | grep -qw "$nome_usuario"; then
                echo "Erro: Falha ao deletar o usuário $nome_usuario. Verifique se há dependências."
            else
                echo "Usuário $nome_usuario, banco de dados e permissões deletados com sucesso!"
            fi
        else
            echo "Operação cancelada."
        fi
    else
        echo "Opção inválida."
    fi
}

# Função para desinstalar o PostgreSQL e remover todos os arquivos relacionados
desinstalar_postgresql() {
    read -p "Tem certeza que deseja desinstalar o PostgreSQL e apagar todos os dados relacionados? (s/n): " confirmacao
    if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
        echo "Parando o serviço PostgreSQL..."
        sudo systemctl stop postgresql

        echo "Removendo o PostgreSQL e todos os pacotes associados..."
        sudo apt-get --purge remove postgresql* -y

        echo "Removendo diretórios de dados do PostgreSQL..."
        sudo rm -rf /var/lib/postgresql/
        sudo rm -rf /etc/postgresql/
        sudo rm -rf /etc/postgresql-common/
        sudo rm -rf /var/log/postgresql/
        sudo rm -rf /usr/lib/postgresql/

        echo "Removendo cache de pacotes PostgreSQL..."
        sudo apt-get clean

        echo "Limpando pacotes não utilizados..."
        sudo apt-get autoremove -y
        sudo apt-get autoclean -y

        echo "Verificando e removendo vestígios no sistema de arquivos..."
        sudo find / -name "*postgresql*" -exec rm -rf {} + 2>/dev/null

        echo "Removendo entradas de serviços e reconfigurando o sistema..."
        sudo systemctl daemon-reload

        echo "PostgreSQL e todos os dados relacionados foram removidos com sucesso!"
    else
        echo "Operação de desinstalação cancelada."
    fi
}

# Função para verificar o tamanho dos bancos de dados
ver_tamanho_bancos() {
    echo "Tamanho dos bancos de dados no PostgreSQL:"
    sudo -u postgres psql -c "SELECT datname AS database_name, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;"
}

# Função para mostrar o limite de conexões do PostgreSQL
mostrar_limite_conexoes() {
    CONFIG_FILE=$(sudo -u postgres psql -t -A -c "SHOW config_file;")
    
    if [ -f "$CONFIG_FILE" ]; then
        max_conexoes=$(grep -E "^max_connections\s*=" "$CONFIG_FILE" | awk -F '=' '{print $2}' | tr -d ' ')
        echo "O limite atual de conexões do PostgreSQL é: $max_conexoes"
    else
        echo "Erro: Arquivo de configuração do PostgreSQL não encontrado."
    fi
}

# Função para alterar o limite de conexões do PostgreSQL
alterar_limite_conexoes() {
    CONFIG_FILE=$(sudo -u postgres psql -t -A -c "SHOW config_file;")

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Erro: Arquivo de configuração do PostgreSQL não encontrado."
        return
    fi

    # Backup do arquivo de configuração
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup_$(date +%d_%m_%Y_%H-%Mhr)"
    echo "Backup do arquivo de configuração criado em ${CONFIG_FILE}.backup_$(date +%d_%m_%Y_%H-%Mhr)}"

    # Solicita o novo limite ao usuário
    while true; do
        read -p "Digite o novo limite de conexões (número inteiro): " novo_limite
        if [[ "$novo_limite" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Entrada inválida. Por favor, insira um número inteiro."
        fi
    done

    # Atualiza o valor no arquivo de configuração
    if grep -q "^max_connections" "$CONFIG_FILE"; then
        sudo sed -i "s/^#*max_connections\s*=.*/max_connections = $novo_limite/" "$CONFIG_FILE"
    else
        echo "max_connections = $novo_limite" | sudo tee -a "$CONFIG_FILE" > /dev/null
    fi

    echo "Limite de conexões atualizado para $novo_limite."

    # Reinicia o serviço PostgreSQL para aplicar as mudanças
    sudo systemctl restart postgresql

    if [ $? -eq 0 ]; then
        echo "Serviço PostgreSQL reiniciado com sucesso."
    else
        echo "Erro ao reiniciar o serviço PostgreSQL."
    fi
}

# Função para habilitar/desabilitar conexões remotas no PostgreSQL
gerenciar_conexoes_remotas() {
    echo "1. Habilitar conexões remotas"
    echo "2. Desabilitar conexões remotas"
    read -p "Escolha uma opção (1 ou 2): " escolha

    CONFIG_FILE=$(sudo -u postgres psql -t -A -c "SHOW config_file;")
    HBA_FILE=$(sudo -u postgres psql -t -A -c "SHOW hba_file;")

    if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$HBA_FILE" ]; then
        echo "Erro: Arquivos de configuração do PostgreSQL não encontrados."
        return
    fi

    # Backup dos arquivos de configuração
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup_$(date +%d_%m_%Y_%H-%Mhr)"
    sudo cp "$HBA_FILE" "${HBA_FILE}.backup_$(date +%d_%m_%Y_%H-%Mhr)"
    echo "Backups dos arquivos de configuração criados."

    case $escolha in
        1)
            # Habilitar conexões remotas
            sudo sed -i "s/^#*listen_addresses\s*=.*/listen_addresses = '*'/" "$CONFIG_FILE"
            echo "listen_addresses configurado para '*'."

            # Adicionar regra para permitir todas as conexões remotas (ajuste conforme necessário)
            if ! grep -q "^host\s\+all\s\+all\s\+0\.0\.0\.0/0\s\+md5" "$HBA_FILE"; then
                echo "host all all 0.0.0.0/0 md5" | sudo tee -a "$HBA_FILE" > /dev/null
                echo "Regra adicionada ao pg_hba.conf para permitir conexões remotas."
            else
                echo "Regra para conexões remotas já existe no pg_hba.conf."
            fi
            ;;
        2)
            # Desabilitar conexões remotas
            sudo sed -i "s/^#*listen_addresses\s*=.*/listen_addresses = 'localhost'/" "$CONFIG_FILE"
            echo "listen_addresses configurado para 'localhost'."

            # Remover regra que permite conexões remotas
            sudo sed -i "/^host\s\+all\s\+all\s\+0\.0\.0\.0\/0\s\+md5/d" "$HBA_FILE"
            echo "Regra para conexões remotas removida do pg_hba.conf."
            ;;
        *)
            echo "Opção inválida."
            return
            ;;
    esac

    # Reinicia o serviço PostgreSQL para aplicar as mudanças
    sudo systemctl restart postgresql

    if [ $? -eq 0 ]; then
        echo "Serviço PostgreSQL reiniciado com sucesso."
    else
        echo "Erro ao reiniciar o serviço PostgreSQL."
    fi
}

# Menu de opções
while true; do
    echo "----------------------------"
    echo "     Gerenciador PostgreSQL"
    echo "----------------------------"
    echo "1. Instalar PostgreSQL"
    echo "2. Criar um novo usuário"
    echo "3. Deletar usuário e banco de dados"
    echo "4. Listar todos os usuários"
    echo "5. Fazer backup do banco de dados"
    echo "6. Restaurar banco de dados"
    echo "7. Ver tamanho dos bancos de dados"
    echo "8. Iniciar PostgreSQL"
    echo "9. Parar PostgreSQL"
    echo "10. Reiniciar PostgreSQL"
    echo "11. Ver status do PostgreSQL"
    echo "12. Desinstalar PostgreSQL e apagar tudo"
    echo "13. Mostrar limite de conexão do PostgreSQL"
    echo "14. Alterar limite de conexão do PostgreSQL"
    echo "15. Habilitar/Desabilitar conexões remotas no PostgreSQL"
    echo "16. Sair"
    echo "----------------------------"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) instalar_postgresql ;;
        2) criar_usuario ;;
        3) deletar_usuario ;;
        4) listar_usuarios ;;
        5) fazer_backup ;;
        6) restaurar_banco ;;
        7) ver_tamanho_bancos ;;
        8) iniciar_postgresql ;;
        9) parar_postgresql ;;
        10) reiniciar_postgresql ;;
        11) status_postgresql ;;
        12) desinstalar_postgresql ;;
        13) mostrar_limite_conexoes ;;
        14) alterar_limite_conexoes ;;
        15) gerenciar_conexoes_remotas ;;
        16) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!";;
    esac
done
