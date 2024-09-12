#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root!"
    exit 1
fi

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

    # Realiza o backup de segurança antes de destruir o banco de dados, se não estiver vazio
    backup_seguranca "$nome_banco"

    read -p "Digite o nome do arquivo SQL na pasta root (ex: backup.sql): " arquivo_sql
    arquivo_sql=$(sanitizar_nome "$arquivo_sql")

    # Adiciona o caminho da pasta root se o arquivo não tiver um caminho especificado
    if [[ "$arquivo_sql" != /* ]]; then
        arquivo_sql="/root/$arquivo_sql"
    fi

    if [ -f "$arquivo_sql" ]; then
        echo "Restaurando o banco de dados $nome_banco a partir do arquivo $arquivo_sql..."
        cd /tmp || exit

        # Destrói e recria o banco de dados antes de restaurar
        recriar_banco "$nome_banco"
        
        # Restaurar o banco de dados
        sudo -u postgres psql "$nome_banco" < "$arquivo_sql" 2>/dev/null
        echo "Restauração concluída com sucesso!"
    else
        echo "Arquivo $arquivo_sql não encontrado!"
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
    echo "1. Listar todos os usuários"
    echo "2. Criar um novo usuário"
    echo "3. Restaurar banco de dados"
    echo "4. Fazer backup do banco de dados"
    echo "5. Deletar usuário e banco de dados"
    echo "6. Sair"
    echo "----------------------------"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) listar_usuarios ;;
        2) criar_usuario ;;
        3) restaurar_banco ;;
        4) fazer_backup ;;
        5) deletar_usuario ;;
        6) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!";;
    esac
done
