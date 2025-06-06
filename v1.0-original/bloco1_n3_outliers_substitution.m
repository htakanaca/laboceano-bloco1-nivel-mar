%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 3: Detecção e Substituição de Outliers dos dados, após o 
% preenchimento de falhas. 
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
arquivo_b1n2 = fullfile(data_dir_b1n1, 'nivel_adcp_suave.mat');




% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diretório onde o script está localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diretório de dados em relação à pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);

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
           data_dir, nome_arquivo);
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
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz numérica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo não suportado.');
end

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
           data_dir, arquivo_b1n2);
end

load(arquivo_b1n2);

%% Definição de parâmetros e variáveis auxiliares:
%
% Explicação sobre o método para entendimento das variáveis a seguir:
%
% Toda a série de nível do mar é percorrida para identificar potenciais 
% Outliers. A série é transformada em primeira derivada, pois a definição
% de Outlier é dada como uma variação brusca no nível do mar, provavelmente
% causada por sinais espúrios ou ondas geradas por passagens de embarcação
% próximo ao local de medição do nível do mar pelo ADCP.
%
% Os Outliers são buscados ao longo de toda a série e testados contra o
% "fator_limiar". Os elementos identificados como Outliers são substituídos 
% por um valor médio entre os valores vizinhos. 
% 

% Renomeia os dados de nível do mar em um vetor separado:
nivel_adcp = dados(:,7);

% Define o fator limiar de variação, acima do qual um ponto será 
% considerado outlier:
fator_limiar = 5;  

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de referência):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Tamanho da série para a substituição de Outliers:
roda_varredura_outlier = tamanho_tempo_total;

% Inicializa contador de outliers:
conta_outliers_nivel = 1;

% Cria a variável de trabalho dos outliers:
nivel_adcp = nivel_adcp_suave;

% Cópia do original para comparação posterior:
nivel_adcp_orig = nivel_adcp; 

% Adiciona valor de +100 para forçar todos os dados a positivos:
nivel_adcp = nivel_adcp + 100;

%% Detecção e substituição de Outliers:
%
% Lógica: 
% 1. Calcula diferenças entre pontos consecutivos (primeira derivada)
% 2. Identifica pontos onde a diferença excede "fator_limiar"
% 3. Substitui outliers por média local (para 1 ponto) ou interpolação 
%    linear (para 2 pontos)

% Inicializa variáveis do Loop principal
% Armazena posições dos outliers corrigidos:
outliers_unicos_nivel = [];  

fprintf('\nIniciando detecção e substituição de outliers...\n');

% Loop principal: 
for ii=2:roda_varredura_outlier-2
    
    % Cálculo da derivada:
    diff_nivel = diff(nivel_adcp(1:ii));
    zscore_diff = (diff_nivel - mean(diff_nivel)) / std(diff_nivel);
    
    % Detecção de candidatos a outlier:
    idx_outliers_candidatos = find(abs(zscore_diff(1:ii-1)) >= fator_limiar);
    
    % Processamento dos candidatos a outlier:
    if length(idx_outliers_candidatos)>0
        
        outliers_corr_int_nivel_POS_nao_nan(1:length(idx_outliers_candidatos))=idx_outliers_candidatos;
        
        % Cria uma matriz de flags de "potenciais outliers = 1" e dados = 0:
        nivel_flags_outliers(1:ii)=zeros;
        nivel_flags_outliers(outliers_corr_int_nivel_POS_nao_nan(1:length(idx_outliers_candidatos)))=1;
        
        % Adiciona zeros nas pontas pra detectar transições no início e
        % fim:
        mudancas_flag_outliers = diff([0 nivel_flags_outliers(:)' 0]);
        transicoes_outliers(1:length(mudancas_flag_outliers)) = mudancas_flag_outliers;
        
        % onde começa grupo de outlier (1):
        nivel_ini = find(transicoes_outliers(:) == 1) ; 
        % onde termina grupo de outlier:
        nivel_fim = find(transicoes_outliers(:) == -1)-1; 
        
        % Tamanhos dos grupos de potenciais outliers:
        nivel_tam_blocos = nivel_fim - nivel_ini + 1;
        
        for jj = 1:length(nivel_tam_blocos)
            if nivel_fim(jj)+2 <= length(nivel_adcp)
                
                % Para até 3 outliers consecutivos, substitui por média 
                % simples:
                if nivel_tam_blocos(jj) < 3
                    if nivel_tam_blocos(jj) == 1
                        fprintf('Grupo %.0f: posição %.0f a %.0f para %.6f (outlier)\n', jj,nivel_ini(jj),nivel_fim(jj));
                        outlier=nivel_adcp(nivel_fim(jj)+1);

                        nivel_adcp(nivel_fim(jj)+1)= ( (nivel_adcp(nivel_fim(jj)+2)) + (nivel_adcp(nivel_fim(jj))) )/2;
                        
                        outlier_corrigido = nivel_adcp(nivel_fim(jj)+1);
                        fprintf('Outlier corrigido: de %.6f para %.6f\n', outlier,outlier_corrigido);
                        
                        outliers_unicos_nivel(conta_outliers_nivel)=nivel_fim(jj)+1;
                        conta_outliers_nivel = conta_outliers_nivel + 1;
                    else
                % Para 3 ou mais outliers consecutivos, substitui por  
                % interpolação linear:
                        fprintf('Grupo %.0f: posição %.0f a %.0f para %.6f (outlier)\n', jj,nivel_ini(jj),nivel_fim(jj));
                        outlier1=nivel_adcp(nivel_fim(jj)+1);
                        outlier2=nivel_adcp(nivel_fim(jj)+2);
                        
                        pedaco = ( nivel_adcp(nivel_fim(jj)+3) - nivel_adcp(nivel_fim(jj)) )/3;
                        nivel_adcp(nivel_fim(jj)+1) = nivel_adcp(nivel_fim(jj)) + pedaco;
                        nivel_adcp(nivel_fim(jj)+2) = nivel_adcp(nivel_fim(jj)+1) + pedaco;
                        
                        outlier1_corrigido = nivel_adcp(nivel_fim(jj)+1);
                        outlier2_corrigido = nivel_adcp(nivel_fim(jj)+2);
                        fprintf('Outliers corrigidos: de %.6f para %.6f e de %.6f para %.6f\n', outlier1,outlier1_corrigido,outlier2_corrigido);
                        
                        outliers_unicos_nivel(conta_outliers_nivel)=nivel_fim(jj)+1;
                        conta_outliers_nivel = conta_outliers_nivel + 1;
                        outliers_unicos_nivel(conta_outliers_nivel)=nivel_fim(jj)+2;
                        conta_outliers_nivel = conta_outliers_nivel + 1;
                    end
                end
            end
        end
    end
    
    if(ii==tempo_total_vetorial(end))
        break
    end
    
    fprintf('ii %.0f\n',ii);
end

% Subtrai o valor de 100 da variável do nível do mar trabalhada:
nivel_adcp_limpo=nivel_adcp-100;

%% Figuras:
% Figura 1: Comparação do sinal original e do sinal limpo de nível do mar,
% em um bloco selecionado da série temporal. A limpeza remove outliers 
% individuais detectados via normalização da diferença temporal (z-score).
%
% A linha vermelha representa o dado original, e a azul o sinal corrigido.

% Define qual bloco será mostrado nos plots:
indice_bloco_plot_ini = 1; 
indice_bloco_plot_fim = tamanho_tempo_total-2; 

figure(1)
clf
hold on
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim),nivel_adcp_orig(indice_bloco_plot_ini:indice_bloco_plot_fim),'-r')
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim),nivel_adcp_limpo(indice_bloco_plot_ini:indice_bloco_plot_fim))
grid;
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Nível (metros)');
title(['Nível (metros) - Exemplo de Bloco de Dados Completos, Std: '...
    ,num2str(std (zscore_diff(indice_bloco_plot_ini:indice_bloco_plot_fim))),', Limiar de Outlier: ',num2str(limiar_corr_int_nivel_nao_nan),' ']);

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

%% Análises Quantitativas da Remoção de Outliers:

outliers_nivel_corrigidos = unique(outliers_unicos_nivel);

% Porcentagem total de pontos de outliers em relação ao total de dados:
quantidade_unica_outliers_nivel = length(unique(outliers_unicos_nivel));
porcentagem_outliers_nivel = (((quantidade_unica_outliers_nivel))/ii);
fprintf('Porcentagem total de outliers do Nível: %.6f\n', porcentagem_outliers_nivel);

% Estatística básica de antes e depois dos outliers:
% média:
media_nivel_antes=mean(nivel_adcp_orig(1:ii-1));
media_nivel_depois=mean(nivel_adcp_limpo(1:ii));
fprintf('Média antes e depois, do Nível: %.6f e %.6f\n', media_nivel_antes, media_nivel_depois);

% std:
std_nivel_antes=std(nivel_adcp_orig(1:ii));
std_nivel_depois=std(nivel_adcp_limpo(1:ii));
fprintf('STD antes e depois do Nível: %.6f e %.6f\n', std_nivel_antes, std_nivel_depois);


figure(3)
clf
hold on
plot(tempo_total_vetorial(outliers_nivel_corrigidos), nivel_adcp_orig(outliers_nivel_corrigidos), 'r')
plot(tempo_total_vetorial(outliers_nivel_corrigidos), nivel_adcp_limpo(outliers_nivel_corrigidos), 'b')
title(['Outliers detectados'])

%% Salva as variáveis

% Formato .mat:

%vetor com as datas em formato datenum:
vetor_datas_num=datenum(dados(:,3),dados(:,2),dados(:,1),dados(:,4),dados(:,5),dados(:,6)); 

save('nivel_adcp_limpo.mat','nivel_adcp_limpo','outliers_nivel_corrigidos','vetor_datas_num');

