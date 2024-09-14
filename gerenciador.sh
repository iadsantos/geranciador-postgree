#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root!"
    exit 1
fi

# Função para instalar o PostgreSQL
instalar_postgresql() {
    if dpkg -l | grep -qw postgresql; then
        echo "PostgreSQL já está instalado."
        return
    fi

    echo "Instalando PostgreSQL 15..."
    sudo apt-get install gnupg -y
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update -y && sudo apt-get -y install postgresql-15
    
    if [ $? -eq 0 ]; then
        echo "PostgreSQL 15 instalado com sucesso!"
        sudo systemctl restart postgresql
    else
        echo "Erro ao instalar o PostgreSQL."
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
    local tabela_existe=$(sudo -u postgres psql -d "$nome_banco" -t -c \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1);" | xargs)

    local possui_dados=$(sudo -u postgres psql -d "$nome_banco" -t -c \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables 
     WHERE table_schema = 'public' 
     AND (SELECT COUNT(*) FROM information_schema.tables 
          WHERE table_schema = 'public') > 0 LIMIT 1);" | xargs)

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
    while true; do
        read -p "Digite o nome do banco de dados que deseja fazer backup: " nome_banco
        nome_banco=$(sanitizar_nome "$nome_banco")

        if [[ -z "$nome_banco" ]] || ! validar_nome "$nome_banco"; then
            echo "Erro: O nome do banco de dados deve conter apenas letras e números e não pode estar vazio."
            continue
        fi

        if ! banco_existe "$nome_banco"; then
            echo "Erro: O banco de dados $nome_banco não existe!"
            continue
        fi

        break
    done

    caminho_backup="/home/backups"

    if [ ! -d "$caminho_backup" ]; then
        echo "Diretório $caminho_backup não existe. Criando..."
        mkdir -p "$caminho_backup"
        chmod 777 "$caminho_backup"
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
    local caminho_backup="/home/backups/seguranca"

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
    read -p "Digite o nome do banco de dados que deseja restaurar: " nome_banco
    nome_banco=$(sanitizar_nome "$nome_banco")

    if ! banco_existe "$nome_banco"; then
        echo "Erro: O banco de dados $nome_banco não existe!"
        return
    fi

    read -p "Digite o nome do arquivo de backup (ex: backup.backup): " arquivo_backup

    if [[ "$arquivo_backup" != /* ]]; then
        arquivo_backup="/home/backups/$arquivo_backup"
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
            banco_usuario=$(sudo -u postgres psql -lqt | cut -d \| -f 1 | awk '{$1=$1};1' | grep -w "$nome_usuario")

            if banco_existe "$banco_usuario"; then
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

# Menu de opções
while true; do
    echo "----------------------------"
    echo "     Gerenciador PostgreSQL"
    echo "----------------------------"
    echo "1. Instalar PostgreSQL"
    echo "2. Iniciar PostgreSQL"
    echo "3. Parar PostgreSQL"
    echo "4. Reiniciar PostgreSQL"
    echo "5. Ver status do PostgreSQL"
    echo "6. Listar todos os usuários"
    echo "7. Criar um novo usuário"
    echo "8. Restaurar banco de dados"
    echo "9. Fazer backup do banco de dados"
    echo "10. Deletar usuário e banco de dados"
    echo "11. Sair"
    echo "----------------------------"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) instalar_postgresql ;;
        2) iniciar_postgresql ;;
        3) parar_postgresql ;;
        4) reiniciar_postgresql ;;
        5) status_postgresql ;;
        6) listar_usuarios ;;
        7) criar_usuario ;;
        8) restaurar_banco ;;
        9) fazer_backup ;;
        10) deletar_usuario ;;
        11) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!";;
    esac
done
