#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root!"
    exit 1
fi

# Função para instalar o PostgreSQL
instalar_postgresql() {
    # Verifica se o PostgreSQL já está instalado
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
        echo "Reiniciando o serviço PostgreSQL..."
        sudo systemctl restart postgresql
    else
        echo "Erro ao instalar o PostgreSQL."
    fi
}

# Função para iniciar o serviço PostgreSQL
iniciar_postgresql() {
    # Verifica se o serviço já está em execução
    if systemctl is-active --quiet postgresql; then
        echo "PostgreSQL já está em execução."
    else
        echo "Iniciando o serviço PostgreSQL..."
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
    echo "Parando o serviço PostgreSQL..."
    sudo systemctl stop postgresql
    echo "Serviço PostgreSQL parado."
}

# Função para reiniciar o serviço PostgreSQL
reiniciar_postgresql() {
    echo "Reiniciando o serviço PostgreSQL..."
    sudo systemctl restart postgresql
    echo "Serviço PostgreSQL reiniciado."
}

# Função para verificar o status do serviço PostgreSQL
status_postgresql() {
    echo "Verificando o status do serviço PostgreSQL..."
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

# Função para desconectar usuários conectados a um banco de dados
desconectar_usuarios() {
    local nome_banco="$1"
    echo "Desconectando usuários do banco de dados $nome_banco..."
    sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$nome_banco';" 2>/dev/null
}

# Função para revogar todas as permissões do usuário em todos os bancos de dados
revogar_permissoes() {
    local nome_usuario="$1"
    echo "Revogando permissões do usuário $nome_usuario..."
    sudo -u postgres psql -c "REASSIGN OWNED BY $nome_usuario TO postgres;" 2>/dev/null
    sudo -u postgres psql -c "DROP OWNED BY $nome_usuario;" 2>/dev/null
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

# Função para criar um backup de segurança do banco de dados antes de restaurar
backup_seguranca() {
    local nome_banco="$1"
    local caminho_backup="/root/bkseguraca"

    # Verifica se o banco de dados está vazio
    if banco_existe "$nome_banco"; then
        echo "O banco de dados $nome_banco está vazio. Nenhum backup de segurança necessário."
        return
    fi

    # Verifica se o diretório de backup de segurança existe, caso contrário, cria
    if [ ! -d "$caminho_backup" ]; then
        echo "Criando o diretório de backup de segurança em $caminho_backup..."
        mkdir -p "$caminho_backup"
    fi

    # Define o nome do arquivo de backup de segurança
    local arquivo_backup="$caminho_backup/${nome_banco}_backup_seguranca_$(date +%Y%m%d%H%M%S).sql"

    echo "Criando backup de segurança do banco de dados $nome_banco para o arquivo $arquivo_backup..."
    cd /tmp || exit
    sudo -u postgres pg_dump "$nome_banco" > "$arquivo_backup"

    if [ $? -eq 0 ]; then
        echo "Backup de segurança concluído com sucesso em $arquivo_backup!"
    else
        echo "Erro ao criar o backup de segurança do banco de dados $nome_banco."
    fi
}

# Função para listar todos os usuários do PostgreSQL
listar_usuarios() {
    echo "Listando todos os usuários do PostgreSQL:"
    cd /tmp || exit
    sudo -u postgres psql -P pager=off -c "\du" 2>/dev/null
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

    cd /tmp || exit

    sudo -u postgres psql -c "CREATE USER $nome_usuario WITH PASSWORD '$senha' SUPERUSER CREATEDB CREATEROLE;" 2>/dev/null
    sudo -u postgres psql -c "CREATE DATABASE $nome_banco OWNER $nome_usuario;" 2>/dev/null
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $nome_banco TO $nome_usuario;" 2>/dev/null

    echo "Usuário $nome_usuario criado com sucesso, com permissões atribuídas, e banco $nome_banco configurado!"
}

# Função para destruir e recriar o banco de dados
recriar_banco() {
    local nome_banco="$1"
    echo "Destruindo o banco de dados $nome_banco..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $nome_banco;" 2>/dev/null
    echo "Recriando o banco de dados $nome_banco..."
    sudo -u postgres psql -c "CREATE DATABASE $nome_banco;" 2>/dev/null
}

# Função para restaurar um banco de dados a partir de um arquivo SQL
restaurar_banco() {
    read -p "Digite o nome do banco de dados que deseja restaurar: " nome_banco
    nome_banco=$(sanitizar_nome "$nome_banco")

    # Verifica se o banco de dados existe
    if ! banco_existe "$nome_banco"; then
        echo "Erro: O banco de dados $nome_banco não existe!"
        return
    fi

    # Realiza o backup de segurança antes de destruir o banco de dados
    backup_seguranca "$nome_banco"

    read -p "Digite o nome do arquivo SQL na pasta root (ex: backup.sql): " arquivo_sql

    # Manter o caminho do arquivo como inserido pelo usuário
    if [[ "$arquivo_sql" != /* ]]; then
        arquivo_sql="/root/$arquivo_sql"
    fi

    # Verifica se o arquivo SQL existe
    if [ -f "$arquivo_sql" ]; then
        echo "Restaurando o banco de dados $nome_banco a partir do arquivo $arquivo_sql..."
        
        # Evite mudar para /root, navegue em diretórios seguros
        cd /tmp || exit

        # Destrói e recria o banco de dados antes de restaurar
        recriar_banco "$nome_banco"
        
        # Restaurar o banco de dados
        sudo -u postgres psql "$nome_banco" < "$arquivo_sql" 2>/dev/null
        echo "Restauração concluída com sucesso!"
    else
        echo "Erro: Arquivo $arquivo_sql não encontrado!"
    fi
}


# Função para criar um backup do banco de dados
fazer_backup() {
    while true; do
        read -p "Digite o nome do banco de dados que deseja fazer backup: " nome_banco
        nome_banco=$(sanitizar_nome "$nome_banco")

        # Verifica se o nome está vazio ou inválido
        if [[ -z "$nome_banco" ]] || ! validar_nome "$nome_banco"; then
            echo "Erro: O nome do banco de dados deve conter apenas letras e números e não pode estar vazio."
            continue
        fi

        # Verifica se o banco de dados existe
        if ! banco_existe "$nome_banco"; then
            echo "Erro: O banco de dados $nome_banco não existe!"
            continue
        fi

        break
    done

    read -p "Digite o caminho completo para salvar o backup (padrão: /root): " caminho_backup
    caminho_backup=$(sanitizar_nome "$caminho_backup")

    # Define o caminho padrão para o root se não for especificado
    if [ -z "$caminho_backup" ]; then
        caminho_backup="/root"
    fi

    # Verifica se o diretório existe, se não existir, cria
    if [ ! -d "$caminho_backup" ]; then
        echo "Diretório $caminho_backup não existe. Criando..."
        mkdir -p "$caminho_backup"
    fi

    # Define o nome do arquivo de backup
    arquivo_backup="$caminho_backup/${nome_banco}_backup_$(date +%Y%m%d%H%M%S).sql"

    # Executa o backup no diretório /tmp para evitar problemas de permissão
    echo "Fazendo backup do banco de dados $nome_banco para o arquivo $arquivo_backup..."
    cd /tmp || exit
    sudo -u postgres pg_dump "$nome_banco" > "$arquivo_backup"

    if [ $? -eq 0 ]; then
        echo "Backup concluído com sucesso em $arquivo_backup!"
    else
        echo "Erro ao fazer o backup do banco de dados $nome_banco."
    fi
}

# Função para deletar um usuário, banco e suas permissões
deletar_usuario() {
    echo "Listando todos os usuários do PostgreSQL:"
    cd /tmp || exit
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

            # Desconectar usuários conectados ao banco de dados
            if banco_existe "$banco_usuario"; then
                desconectar_usuarios "$banco_usuario"
                sudo -u postgres psql -c "DROP DATABASE IF EXISTS $banco_usuario;" 2>/dev/null
            fi
            
            # Revogar permissões e excluir o usuário
            revogar_permissoes "$nome_usuario"
            sudo -u postgres psql -c "DROP USER IF EXISTS $nome_usuario;" 2>/dev/null
            
            # Verificar se o usuário foi removido
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
