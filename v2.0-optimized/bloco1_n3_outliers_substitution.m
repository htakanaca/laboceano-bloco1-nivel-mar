%
% Versão: 2.0-Optmized
%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 3: Detecção e Substituição de Outliers dos dados, após o
% preenchimento de falhas.
%
% Este script utiliza a FUNÇÂO "limpa_outliers.m" que pode ser baixada em:
% https://github.com/htakanaca/AI-Assisted-Learning/blob/main/Matlab/Gemini/limpar_outliers.m
%
% Aplicação: Dados de NÌVEL DO MAR de ADCP da Bóia BH07, na Baía de
% Guanabara.
%
% Este script realiza a detecção e substituição de outliers nos dados
% pré-processados, utilizando análise de derivadas e ajuste local com
% valores médios, garantindo a continuidade e qualidade da série temporal.
%
% Hatsue Takanaca de Decco, Junho/2025.
%
% Contribuições de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio da inteligência
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio e junho de 2025,
% e Gemini (Gooogle AI) em junho de 2025.
% A lógica foi construída a partir de instruções e ajustes
% fornecidos pela pesquisadora, garantindo coerência com os
% objetivos e critérios do estudo.
%
% A coautoria simbólica da IA é reconhecida no aspecto técnico,
% sem implicar autoria científica ou responsabilidade intelectual.
%
% Respositório (em desenvolvimento) de suporte didático por IA para
% conteúdos relacionados ao processamento de dados em:
% https://github.com/htakanaca/AI-Assisted-Learning
% ------------------------------------------------------------
%
% Dados de Nível do Mar (metros):
% - Frequência amostral: 5 minutos.
% - Período: conforme arquivo de entrada.
%
% ATENÇÃO:
%
% - A definição de outlier e o fator limiar devem ser calibrados conforme
% as características da série analisada.
%
% ETAPA DO FLUXOGRAMA:
% Pós-processamento (etapa 3) - Deve ser executado APÓS:
%   1. Preenchimento de falhas com U-Tide
%      (bloco1_n1_gapfilling_tide_codiga2011.m)
%   2. Blending/suavização de offsets
%      (bloco1_n2_offsets_blending_smooth.m)
%

clear
clc

%% Abertura e Organização dos dados

% === CONFIGURAÇÃO DO USUÁRIO ===
% Defina aqui o nome do arquivo onde estão os dados originais, que
% ainda contém falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc
% Nome da série de previsão harmônica previamente ajustada com o U-Tide
% (salva pelo script "bloco1_n2_offsets_blending_smooth.m"):
nomedoarquivo_b1n2 = 'nivel_adcp_suave.mat';
%
% OUTPUT:
% Nome do arquivo de output, com os dados preenchidos com previsão de maré
% e com os offsets com blending e suavização, formato CSV):
filename_output_csv = './Dados/nivel_adcp_limpo.csv';
% formato .mat:
filename_output_mat = './Dados/nivel_adcp_limpo.mat';
%
% === FIM DA CONFIGURAÇÃO DO USUÁRIO ===


% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diretório onde o script está localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diretório de dados em relação à pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);
% Nome da série de previsão harmônica previamente ajustada com o U-Tide
% (salva pelo script "bloco1_n2_offsets_blending_smooth.m"):
arquivo_b1n2 = fullfile(data_dir, nomedoarquivo_b1n2);

% Leitura dos dados originais para referência:
% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATENÇÃO!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO NÃO ENCONTRADO!\n\n' ...
        'Verifique se o diretório está correto:\n  %s\n\n' ...
        'E se o nome do arquivo está correto:\n  %s\n\n'], ...
        data_dir, nomedoarquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATENÇÃO: ===
        % Este comando carrega a **primeira variável** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT não contém variáveis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1ª variável!
        
        % => Garanta que essa variável seja a que contém os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,Nível (metros)
        % Caso não seja, altere 'vars(1).name' para o nome correto da variável.
        
        % Otimização: Carrega para uma struct e acessa o campo
        data_struct = load(arquivo, nome_var);
        dados = data_struct.(nome_var); % Acessa a variável pelo nome
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz numérica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo não suportado.');
end

% Leitura dos dados originais com lacunas preenchidas e com blending/
% suavizados:
% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n2, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATENÇÃO!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO NÃO ENCONTRADO!\n\n' ...
        'Verifique se o diretório está correto:\n  %s\n\n' ...
        'E se o nome do arquivo está correto:\n  %s\n\n'], ...
        data_dir, nomedoarquivo_b1n2);
end

% Carrega direto para a variável de mesmo nome:
load(arquivo_b1n2, 'nivel_adcp_suave');
% "nivel_adcp_suave" agora está no workspace.

fprintf('Leitura dos arquivos feita com sucesso\n')


%% Definição de parâmetros e variáveis auxiliares:

% Renomeia os dados de nível do mar em um vetor separado:
nivel_adcp_orig = dados(:,7);

% Cria a variável de trabalho dos outliers:
nivel_adcp = nivel_adcp_suave;

% Define o fator limiar de variação, acima do qual um ponto será
% considerado outlier:
fator_limiar = 5;

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de referência):
tempo_total_vetorial = 1:tamanho_tempo_total;

%% Detecção e substituição de Outliers:
%
% Explicação sobre o método para entendimento das variáveis a seguir:
%
% A substituição de outliers é feita utilizando uma função criada para este
% fim. Nela, a série é transformada em primeira derivada, pois a definição
% de Outlier é dada como uma variação brusca no nível do mar, provavelmente
% causada por sinais espúrios ou ondas geradas por passagens de embarcação
% próximo ao local de medição do nível do mar pelo ADCP.
% A seguir, é calculada a medida estatística Z-score, com o qual é possível
% definir o quanto a variação de nível do mar se distancia do desvio padrão
% da série, dando robustez estatística à análise. Uma explicação sobre o 
% Z-score com abordagem mais didática, gerada em colaboração com o Gemini 
% - modelo de linguagem da Google, pode ser encontrada em:
%   https://github.com/htakanaca/AI-Assisted-Learning/blob/main/Z-score-content/Gemini/zscore_explicacao-ptbr.md
% 
% Os Outliers são buscados ao longo de toda a série e testados contra o
% "fator_limiar". Os elementos da série identificados como Outliers são 
% substituídos por um valor médio entre os valores vizinhos.
%

fprintf('\nIniciando detecção e substituição de outliers...\n');

% Definição do método de interpolação usado na função de substituição de
% outliers:
% Escolha um dos métodos:
% 'linear', 'spline', 'pchip', 'nearest', 'next', 'previous'
metodo_interp = ['linear'];

[nivel_adcp_limpo,pontos_outliers_corrigidos] = limpar_outliers(nivel_adcp, fator_limiar,metodo_interp);

%% Figuras:
% Figura 1: Comparação do sinal original e do sinal limpo de nível do mar,
% em um bloco selecionado da série temporal. A limpeza remove outliers
% individuais detectados via normalização da diferença temporal (z-score).
%
% A linha vermelha representa o dado original, e a azul o sinal corrigido.

% Define qual bloco será mostrado nos plots:
indice_bloco_plot_ini = 1;
indice_bloco_plot_fim = tamanho_tempo_total;

figure(1)
clf
hold on
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim),nivel_adcp_orig(indice_bloco_plot_ini:indice_bloco_plot_fim),'-r')
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim),nivel_adcp_limpo(indice_bloco_plot_ini:indice_bloco_plot_fim))
grid;
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Nível (metros)');
title(['Nível (metros) - Exemplo de Bloco de Dados Completos, Limiar de Outlier: ',num2str(fator_limiar),' ']);

% Figura 2: Diferença temporal entre pontos consecutivos da série (diff).
% Essa análise evidencia as variações bruscas, auxiliando na detecção
% de outliers. Sinais suavizados devem apresentar diffs mais homogêneos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(2)
clf
hold
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim-1),diff(nivel_adcp_orig(indice_bloco_plot_ini:indice_bloco_plot_fim)),'r')
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim-1),diff(nivel_adcp_limpo(indice_bloco_plot_ini:indice_bloco_plot_fim)))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferença do Nível (metros)');
grid;
title(['Diff do Nível (metros)']);

figure(3)
clf
hold on
plot(tempo_total_vetorial(pontos_outliers_corrigidos), nivel_adcp_orig(pontos_outliers_corrigidos), 'r')
plot(tempo_total_vetorial(pontos_outliers_corrigidos), nivel_adcp_limpo(pontos_outliers_corrigidos), 'b')
title(['Outliers detectados'])

%% Análises Quantitativas da Remoção de Outliers:

% >> COMENTÁRIO GEMINI: Cálculo simplificado de estatísticas.
% Porcentagem total de pontos de outliers em relação ao total de dados:
quantidade_outliers_nivel = length(pontos_outliers_corrigidos);
porcentagem_outliers_nivel = (quantidade_outliers_nivel*100)/tamanho_tempo_total;
fprintf('\n--- Estatísticas da Limpeza ---\n');
fprintf('Total de pontos na série: %d\n', tamanho_tempo_total);
fprintf('Total de outliers corrigidos: %d\n', quantidade_outliers_nivel);
fprintf('Porcentagem de outliers na série: %.4f %%\n', porcentagem_outliers_nivel);

% Estatística básica de antes e depois dos outliers:
% zera a série original onde tinha falha amostral apenas para estimar a
% média e std originais da série "bruta":
nivel_adcp_orig (isnan(nivel_adcp_orig)) = 0;
fprintf('Média antes: %.6f | Média depois: %.6f\n', mean(nivel_adcp_orig), mean(nivel_adcp_limpo));
fprintf('STD antes:   %.6f | STD depois:   %.6f\n', std(nivel_adcp_orig), std(nivel_adcp_limpo));
fprintf('--------------------------------\n');

%% Salva as variáveis

% Formato .mat:
fprintf('Salvando arquivo MAT...\n')

save (filename_output_mat,'nivel_adcp_limpo','pontos_outliers_corrigidos');

% Formato .csv:
fprintf('Salvando arquivo CSV...\n')

dados_limpos = dados(1:tamanho_tempo_total,1:6);
dados_limpos(:,7) = nivel_adcp_limpo;

% Assumindo que 'dados_preenchidos' é uma matriz numérica de 7 colunas
% [DD,MO,YYYY,HH,MM,SS,Nivel(m)]

% Crie uma tabela a partir da sua matriz para aproveitar o writetable
% E defina os nomes das colunas (cabeçalho)
T = array2table(dados_limpos, 'VariableNames', {'DD','MO','YYYY','HH','MM','SS','Nivel_m'});

% Salva a tabela no formato CSV:
writetable(T, filename_output_csv, ...
    'Delimiter', ';', ... % Seu delimitador é ponto e vírgula
    'WriteVariableNames', true, ... % Escreve os nomes das variáveis (cabeçalho)
    'QuoteStrings', false, ... % Evita aspas em volta dos números, se não forem strings
    'FileType', 'text'); % Especifica que é um arquivo de texto

fprintf('Feito!\n')
