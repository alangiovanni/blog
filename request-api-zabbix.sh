#!/bin/bash
### Author: Alan Giovanni
### E-mail: agmtargino@gmail.com
### Description: O Script possui a função de Adicionar template, Grupos de Host, Aplicações, Itens, itens dependentes e Triggers no Template definido na variável TEMPLATE_NAME.
### A comunicação com o Zabbix é feita via API.
### Data: 30/10/2020

function autenticacao() {
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "user.login",
                "params": {
                        "user": "'$USER'",
                        "password": "'$PASSWORD'"
                },
                "id":1,
                "auth":null
        }
        '
        curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f8
}

function get_templateId() {
        template_name_informado=$1
        JSON='
                {
                        "jsonrpc": "2.0",
                        "method": "template.get",
                        "params": {
                                "output": "templateid",
                                "filter": {
                                        "host": [
                                                "'$template_name_informado'"
                                        ]
                                }
                        },
                "auth": "'$AUTH_TOKEN'",
                "id": "1"
                }
        '
        curl -s -X GET -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
}

function get_applicationId() {
        app_name=$1
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "application.get",
                "params": {
                        "output": "applicationid",
                        "hostids": "'$TEMPLATE_ID'",
                        "filter": {
                                "name": "'$app_name'"
                        }
                },
        "auth": "'$AUTH_TOKEN'",
        "id": "1"
        }
        '
        curl -s -X GET -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
}

function get_groupId() {
        grupo_name=$1
        JSON='
        {
            "jsonrpc": "2.0",
            "method": "hostgroup.get",
            "params": {
                "output": "groupid",
                "filter": {
                    "name": "'$grupo_name'"
                }
            },
            "auth": "'$AUTH_TOKEN'",
            "id": 1
        }
        '
        curl -s -X GET -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
}

function get_triggerId(){
        description=$1
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "trigger.get",
                "params": {
                        "output": [
                                "triggerid"
                        ],
                        "filter": {
                                "description": "'$description'",
                                "hostid": "'$TEMPLATE_ID'"
                        }
                },
                "auth": "'$AUTH_TOKEN'",
                "id": 1
        }
        '
        curl -s -X GET -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
}

function get_itemId() {
        item_name=$1
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "item.get",
                "params": {
                        "output": "itemid",
                        "hostids": "'$TEMPLATE_ID'",
                        "filter": {
                                "name": "'$item_name'"
                        }
                },
        "auth": "'$AUTH_TOKEN'",
        "id": "1"
        }
        '
        curl -s -X GET -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
}

function create_application() {
        app=$1
        JSON='
        {
            "jsonrpc": "2.0",
            "method": "application.create",
            "params": {
                "name": "'$app'",
                "hostid": "'$TEMPLATE_ID'"
            },
            "auth": "'$AUTH_TOKEN'",
            "id": "1"
        }
        '
        # Esse curl retorna o ID da aplicação após criado ou a string "message" se tiver ocorrido problemas na criação da APP
        # curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL" | cut -s -d '"' -f10
        curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL" > /dev/null
}

function create_item() {
        name_item=$1
        url=$2
        key=$3
        type=$4
        value_type=$5
        delay=$6
        app_id=$7

        JSON='
        {
                "jsonrpc": "2.0",
                "method": "item.create",
                "params": {
                        "url":"'$url'",
                        "type":"'$type'",
                        "hostid": "'$TEMPLATE_ID'",
                        "delay":"'$delay'",
                        "key_":"'$key'",
                        "name":"'$name_item'",
                        "value_type":"'$value_type'",
                        "follow_redirects":"0",
                        "timeout":"5s",
                        "history":"'$HISTORY'",
                        "trends": "'$TRENDS'",
                        "applications": [
                                "'$app_id'"
                        ]
                },
                "auth": "'$AUTH_TOKEN'",
                "id": "1"
        }'
        #Retorna o id do item ou Se der erro, retorna o texto "message"
        resultado=$(curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL")
        if [ $(echo $resultado | cut -s -d '"' -f 10 | grep "^[ [:digit:] ]*$") ]; then
                echo "Criação do Item: $name_item [OK]."
        elif [ "$(echo $resultado | grep "already exists")" ]; then
                # Conflito ao criar o item
                echo "Criação do Item: $name_item [FAIL] - Item já existe no template."
        else
                # Problemas não mapeados
                echo "Trigger: $name_trigger [FAIL] - $(echo $resultado | cut -s -d '"' -f 15,16,17,18,19)"
        fi
}

function create_grupos() {
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "hostgroup.create",
                "params": {
                "name": "'$TEMPLATE_GROUP'"
                },
                "auth": "'$AUTH_TOKEN'",
                "id": "1"
        }
        '
        #Retorna o id do item ou Se der erro, retorna o texto "message"
        resultado=$(curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL")
        if [ $(echo $resultado | cut -s -d '"' -f 10 | grep "^[ [:digit:] ]*$") ]; then
                echo "GRUPO: $TEMPLATE_GROUP [OK]."
        elif [ "$(echo $resultado | grep "already exists")" ]; then
                # Conflito ao criar o item
                echo "GRUPO: $TEMPLATE_GROUP [FAIL] - Grupo já existe no Zabbix."
        else
                # Problemas não mapeados
                echo "GRUPO: $TEMPLATE_GROUP [FAIL] - $(echo $resultado | cut -s -d '"' -f 15,16,17,18,19)"
        fi
}

function create_template() {
        group_id=$1
        JSON='
        {
            "jsonrpc": "2.0",
            "method": "template.create",
            "params": {
                "host": "'$TEMPLATE_NAME'",
                "groups": {
                    "groupid": '$group_id'
                }
            },
            "auth": "'$AUTH_TOKEN'",
            "id": 1
        }
        '
        #Retorna o id do item ou Se der erro, retorna o texto "message"
        resultado=$(curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL")
        if [ $(echo $resultado | cut -s -d '"' -f 10 | grep "^[ [:digit:] ]*$") ]; then
                echo "TEMPLATE: $TEMPLATE_NAME [OK]."
        elif [ "$(echo $resultado | grep "already exists")" ]; then
                # Conflito ao criar o item
                echo "TEMPLATE: $TEMPLATE_NAME [FAIL] - Template já existe no Zabbix."
        else
                # Problemas não mapeados
                echo "TEMPLATE: $TEMPLATE_NAME [FAIL] - $(echo $resultado | cut -s -d '"' -f 15,16,17,18,19)"
        fi
}

function create_trigger() {
        name_trigger=$1
        expression=$2
        priority=$3

        JSON='
    {
        "jsonrpc": "2.0",
        "method": "trigger.create",
        "params": [
            {
                "description": "'$name_trigger'",
                "expression": "'$expression'",
                "priority": "'$priority'",
                "hostid": "'$TEMPLATE_ID'"
            }
        ],
        "auth": "'$AUTH_TOKEN'",
        "id": 1
    }
    '
        #Retorna o id do item ou Se der erro, retorna o texto "message"
        resultado=$(curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL")
        if [ $(echo $resultado | cut -s -d '"' -f 10 | grep "^[ [:digit:] ]*$") ]; then
                echo "Trigger: $name_trigger [OK]."
        elif [ "$(echo $resultado | grep "already exists")" ]; then
                # Conflito ao criar o item
                echo "Trigger: $name_trigger [FAIL] - Trigger já existe no template."
        else
                # Problemas não mapeados
                echo "Trigger: $name_trigger [FAIL] - $(echo $resultado | cut -s -d '"' -f 15,16,17,18,19)"
        fi
}

function create_item_dependent() {
        name_item=$1
        key=$2
        master_itemid=$3
        value_type=$4
        params_preprocessing=$5
        app_id=$6
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "item.create",
                "params": {
                        "hostid": "'$TEMPLATE_ID'",
                        "name": "'$name_item'",
                        "key_": "'$key'",
                        "type": "18",
                        "history": "'$HISTORY'",
                        "trends": "'$TRENDS'",
                        "master_itemid": "'$master_itemid'",
                        "value_type": "'$value_type'",
                        "applications": [ "'$app_id'" ],
                        "preprocessing": [ 
                        {
                                "type": "12",
                                "params": "'$params_preprocessing'",
                                "error_handler": 0,
                                "error_handler_params": ""
                        }
                        ]
                },
                "auth": "'$AUTH_TOKEN'",
                "id": "1"
        }'

        #Retorna o id do item ou Se der erro, retorna o texto "message"
        resultado=$(curl -s -X POST -H "$HEADER" -d "$JSON" -i "$URL")
        if [ $(echo $resultado | cut -s -d '"' -f 10 | grep "^[ [:digit:] ]*$") ]; then
                echo "Item Dependente: $name_item [OK]."
        elif [ "$(echo $resultado | grep "already exists")" ]; then
                # Conflito ao criar o item
                echo "Item Dependente: $name_item [FAIL] - Item dependente já existe no template."
        else
                # Problemas não mapeados
                echo "Item Dependente: $name_item [FAIL] - $(echo $resultado | cut -s -d '"' -f 15,16,17,18,19)"
        fi

}

function validaId() {
        teste=$1
        mensagem=$2
        if [ ! "$(echo $teste | grep "^[ [:digit:] ]*$")" ]; then
                echo "$mensagem - Processo Interrompido."
                exit 1
        fi
}

function valida_comunicacao_api_zabbix() {
        curl -s -X GET -H "$HEADER" -i "$URL" > /dev/null && resposta=TRUE || resposta=FALSE
        if [ $resposta = "FALSE" ]; then
                echo "ERRO: Falha na comunicação com a API do Zabbix. Valide as informações setadas nas variáveis de ambiente deste script e verifique o Firewall."
                exit 1
        fi
}

function main() {
        # Valido a comunicação com o Zabbix
        valida_comunicacao_api_zabbix

        # Grupo - Tento criar o grupo do template se não houver
        create_grupos #Cria o grupo predefinido na variável de ambiente

        # Coleto o ID do Grupo definido
        group_id=$(get_groupId $TEMPLATE_GROUP)
        # Valido aqui se a resposta foi um ID de um grupo válido
        validaId $group_id "Erro ao pegar ID do Grupo do Template Principal: $TEMPLATE_NAME"

        # TEMPLATE - Tento criar o template se não tiver criado
        create_template $group_id

        # Coleto o ID do Template definido
        TEMPLATE_ID=$(get_templateId "$TEMPLATE_NAME")
        # Valido aqui se a resposta foi um ID válido
        validaId $TEMPLATE_ID "Erro ao pegar ID do Template Principal: $TEMPLATE_NAME"

        # Tento criar a aplicação no template
        create_application "API Clima"
        # Coleto o ID da aplicação
        app_id=$(get_applicationId "API Clima")
        # Valido aqui se a resposta é um ID válido
        validaId $app_id

        # Criando um item para realizar uma requisição HTTP
        # Ordem dos parâmetros: Nome do Item, URL, Key, Tipo do Item, Tipo do dado, Delay e ID da Aplicação
        create_item "Request HG Weather" "https://api.hgbrasil.com/weather" "request-api-weather" "19" "4" "1m" "$app_id"

        # Criando um item dependente de outro
        # Coleto o ID do item Pai
        master_itemid=$(get_itemId "Request HG Weather")
        if [ $(echo $master_itemid | grep "^[ [:digit:] ]*$") ]; then
                # Caso seja um ID válido, é criado os itens filhos.
                # Ordem dos parâmetros: Nome do Item dependente, Key, ID do item Pai, Tipo do dado, formula do preprocessamento (JSON) e ID da Aplicação
                create_item_dependent "Temperatura" "request-api-weather.temperature" "$master_itemid" "3" "\$.results.condition_code" "$app_id"
                create_item_dependent "Descrição" "request-api-weather.description" "$master_itemid" "4" "\$.results.description" "$app_id"
                create_item_dependent "Nome da Cidade" "request-api-weather.city_name" "$master_itemid" "4" "\$.results.city_name" "$app_id"
        fi

        # Criando alerta
        # Ordem dos parâmetros: Nome da Trigger, Fórmula e ID que corresponde a prioridade do alerta (Information, Average, High..)
        create_trigger "API de Clima HG Weather - Indisponível" "{$TEMPLATE_NAME:request-api-weather.nodata(5m)}=1" "4"
}

## VARIÁVEIS DE AMBIENTE
### REQUEST
SERVER="http://192.168.75.130/zabbix" # Coloque a URL do Zabbix Server
URL="$SERVER/api_jsonrpc.php"
HEADER='Content-Type: application/json-rpc'

### Credenciais de acesso. Comunicação com a API. Estas credenciais precisam ser criadas no Zabbix em "Administration > Users > Create User"
USER='Integração_API_Zabbix'
PASSWORD='CdGhj897!*'

### Algumas definições padrões para criação dos itens
TRENDS='180d' # Dias
HISTORY='7d' # Dias

### TEMPLATE
TEMPLATE_NAME="Template LAB API Clima"
TEMPLATE_GROUP="Tutorial/Templates/LAB"
TEMPLATE_ID="" # Preenchido na função main

### TOKEN DA AUTENTICAÇÃO NA API ZABBIX
AUTH_TOKEN=$(autenticacao)

## START DA MÁGICA
main