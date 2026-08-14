#Requires -Version 5.1
<#
.SYNOPSIS
Tabla de precios estimados por modelo (USD) - dot-sourcable desde argos-stats.ps1.

.DESCRIPTION
Define Get-ModelPricePerToken, que devuelve el costo estimado en USD por TOKEN
(promedio input/output) segun el modelo. Los precios de la tabla estan expresados
por 1M de tokens; la funcion los divide por 1,000,000 para devolver el precio por
token. No imprime nada al ser dot-sourced.
#>

function Get-ModelPricePerToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName
    )

    $name = $ModelName.Trim().ToLowerInvariant()
    if (-not $name) { return [double](0.35 / 1000000.0) }

    # Precios promedio USD por 1M tokens (input+output). El orden importa:
    # se recorre de arriba a abajo y gana la primera coincidencia parcial.
    # 'deepseek' va al final para que 'deepseek v4 pro' no caiga en flash.
    $priceTable = @(
        @{ Keyword = 'flash';    PricePerM = 0.21 },  # DeepSeek V4 Flash  (0.14 in / 0.28 out)
        @{ Keyword = 'pro';      PricePerM = 0.42 },  # DeepSeek V4 Pro    (0.28 in / 0.56 out)
        @{ Keyword = 'luna';     PricePerM = 1.00 },  # GPT-5.6 Luna       (0.40 in / 1.60 out)
        @{ Keyword = 'qwen';     PricePerM = 1.50 },  # Qwen3.8 Max        (0.60 in / 2.40 out)
        @{ Keyword = 'deepseek'; PricePerM = 0.21 }   # deepseek a secas   -> Flash
    )

    foreach ($row in $priceTable) {
        if ($name -like "*$($row.Keyword)*") {
            return [double]($row.PricePerM / 1000000.0)
        }
    }

    # Fallback generico para modelos desconocidos: $0.35 por 1M tokens
    return [double](0.35 / 1000000.0)
}
