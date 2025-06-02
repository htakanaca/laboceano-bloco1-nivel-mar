LabOceano :: Bloco 1 :: Nível do Mar
Scripts de Processamento LabOceano – Dados de Nível do Mar de ADCP na Baía de Guanabara.

Este repositório contém os scripts utilizados para o preenchimento de falhas amostrais nos dados de nível do mar obtidos por ADCP da Bóia BH07, localizada na Baía de Guanabara. O método de preenchimento emprega previsão harmônica de maré utilizando o pacote U-Tide (Codiga, 2011) e, posteriormente, aplica suavização de offsets gerados pela previsão e substituição de outliers.


Estrutura do Repositório

scripts/: Scripts MATLAB para análise e processamento dos dados de nível do mar.

output/: Arquivos gerados após o processamento (sem dados brutos).


LICENSE: Termos de licença do pacote U-Tide.

Importante: os dados originais utilizados neste estudo não estão disponibilizados neste repositório por questões legais e de confidencialidade.


Ferramentas e Métodos
MATLAB: desenvolvimento e execução dos scripts.

U-Tide: pacote MATLAB para análise harmônica de maré.

Processamento: identificação automática de falhas amostrais (NaN), preenchimento por previsão harmônica ajustada com correção de offset, suavização de offsets restantes e substituição de outliers por média simples dos vizinhos.

Autoria e Colaboração
Desenvolvido por Hatsue Takanaca de Decco
Contato: takanaca@gmail.com

Com apoio técnico da inteligência artificial ChatGPT (OpenAI) e Grok (xAI), maio de 2025.

Licença
Este repositório inclui scripts que utilizam o pacote U-Tide, distribuído sob a licença BSD. Consulte o arquivo LICENSE para mais informações.

Link
https://github.com/htakanaca/laboceano-bloco1-nivel-mar
