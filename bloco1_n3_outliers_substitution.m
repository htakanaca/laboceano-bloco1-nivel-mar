%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 3: Detec��o e Substitui��o de Outliers dos dados, ap�s o 
% preenchimento de falhas. 
% 
% Aplica��o: Dados de N�VEL DO MAR de ADCP da B�ia BH07, na Ba�a de 
% Guanabara.
%
% Este script realiza a detec��o e substitui��o de outliers nos dados 
% pr�-processados, utilizando an�lise de derivadas e ajuste local com 
% valores m�dios, garantindo a continuidade e qualidade da s�rie temporal.
%
% Hatsue Takanaca de Decco, Junho/2025.
%
% Contribui��es de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio da intelig�ncia
% artificial ChatGPT (OpenAI), em maio e junho de 2025.
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica da IA � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% Dados de N�vel do Mar (metros):
% - Frequ�ncia amostral: 5 minutos.
% - Per�odo: conforme arquivo de entrada.
%
% ATEN��O:
%
% - A defini��o de outlier e o fator limiar devem ser calibrados conforme  
% as caracter�sticas da s�rie analisada.
%
% ETAPA DO FLUXOGRAMA:
% P�s-processamento (etapa 3) - Deve ser executado AP�S:
%   1. Preenchimento de falhas com U-Tide 
%      (bloco1_n1_gapfilling_tide_codiga2011.m)
%   2. Blending/suaviza��o de offsets 
%      (bloco1_n2_offsets_blending_smooth.m)
%

clear
clc

%% Abertura e Organiza��o dos dados

% === CONFIGURA��O DO USU�RIO ===
% Defina aqui o caminho para o diret�rio onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para fins de compara��o posterior:
data_dir = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Define o nome do arquivo de dados:
nome_arquivo = 'nomedoarquivo.mat'; % .mat, .txt, etc
arquivo = fullfile(data_dir, nome_arquivo);

% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATEN��O!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO N�O ENCONTRADO!\n\n' ...
           'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
           'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
           data_dir, nome_arquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATEN��O: ===
        % Este comando carrega a **primeira vari�vel** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT n�o cont�m vari�veis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1� vari�vel!
        
        % => Garanta que essa vari�vel seja a que cont�m os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,N�vel (metros)
        % Caso n�o seja, altere 'vars(1).name' para o nome correto da vari�vel.
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz num�rica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo n�o suportado.');
end


% Defina aqui o caminho para o diret�rio onde est� o arquivo da s�rie com 
% lacunas de dados preenchidas com previs�o do U-Tide e ap�s o blending e 
% suaviza��o de offsets
% (salva pelo script "bloco1_n2_offsets_blending_smooth.m"):
data_dir_b1n2 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Carrega a s�rie:
arquivo_b1n2 = fullfile(data_dir_b1n2, 'nivel_adcp_suave.mat');

% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n2, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATEN��O!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO N�O ENCONTRADO!\n\n' ...
           'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
           'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
           data_dir_b1n2, arquivo_b1n2);
end

load(arquivo_b1n2);

%% Defini��o de par�metros e vari�veis auxiliares:
%
% Explica��o sobre o m�todo para entendimento das vari�veis a seguir:
%
% Toda a s�rie de n�vel do mar � percorrida para identificar potenciais 
% Outliers. A s�rie � transformada em primeira derivada, pois a defini��o
% de Outlier � dada como uma varia��o brusca no n�vel do mar, provavelmente
% causada por sinais esp�rios ou ondas geradas por passagens de embarca��o
% pr�ximo ao local de medi��o do n�vel do mar pelo ADCP.
%
% Os Outliers s�o buscados ao longo de toda a s�rie e testados contra o
% "fator_limiar". Os elementos identificados como Outliers s�o substitu�dos 
% por um valor m�dio entre os valores vizinhos. 
% 

% Renomeia os dados de n�vel do mar em um vetor separado:
nivel_adcp = dados(:,7);

% Define o fator limiar de varia��o, acima do qual um ponto ser� 
% considerado outlier:
fator_limiar = 5;  

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de refer�ncia):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Tamanho da s�rie para a substitui��o de Outliers:
roda_varredura_outlier = tamanho_tempo_total;

% Inicializa contador de outliers:
conta_outliers_nivel = 1;

% Cria a vari�vel de trabalho dos outliers:
nivel_adcp = nivel_adcp_suave;

% C�pia do original para compara��o posterior:
nivel_adcp_orig = nivel_adcp; 

% Adiciona valor de +100 para for�ar todos os dados a positivos:
nivel_adcp = nivel_adcp + 100;

%% Detec��o e substitui��o de Outliers:
%
% L�gica: 
% 1. Calcula diferen�as entre pontos consecutivos (primeira derivada)
% 2. Identifica pontos onde a diferen�a excede "fator_limiar"
% 3. Substitui outliers por m�dia local (para 1 ponto) ou interpola��o 
%    linear (para 2 pontos)

% Inicializa vari�veis do Loop principal
% Armazena posi��es dos outliers corrigidos:
outliers_unicos_nivel = [];  

fprintf('\nIniciando detec��o e substitui��o de outliers...\n');

% Loop principal: 
for ii=2:roda_varredura_outlier-2
    
    % C�lculo da derivada:
    diff_nivel = diff(nivel_adcp(1:ii));
    zscore_diff = (diff_nivel - mean(diff_nivel)) / std(diff_nivel);
    
    % Detec��o de candidatos a outlier:
    idx_outliers_candidatos = find(abs(zscore_diff(1:ii-1)) >= fator_limiar);
    
    % Processamento dos candidatos a outlier:
    if length(idx_outliers_candidatos)>0
        
        outliers_corr_int_nivel_POS_nao_nan(1:length(idx_outliers_candidatos))=idx_outliers_candidatos;
        
        % Cria uma matriz de flags de "potenciais outliers = 1" e dados = 0:
        nivel_flags_outliers(1:ii)=zeros;
        nivel_flags_outliers(outliers_corr_int_nivel_POS_nao_nan(1:length(idx_outliers_candidatos)))=1;
        
        % Adiciona zeros nas pontas pra detectar transi��es no in�cio e
        % fim:
        mudancas_flag_outliers = diff([0 nivel_flags_outliers(:)' 0]);
        transicoes_outliers(1:length(mudancas_flag_outliers)) = mudancas_flag_outliers;
        
        % onde come�a grupo de outlier (1):
        nivel_ini = find(transicoes_outliers(:) == 1) ; 
        % onde termina grupo de outlier:
        nivel_fim = find(transicoes_outliers(:) == -1)-1; 
        
        % Tamanhos dos grupos de potenciais outliers:
        nivel_tam_blocos = nivel_fim - nivel_ini + 1;
        
        for jj = 1:length(nivel_tam_blocos)
            if nivel_fim(jj)+2 <= length(nivel_adcp)
                
                % Para at� 3 outliers consecutivos, substitui por m�dia 
                % simples:
                if nivel_tam_blocos(jj) < 3
                    if nivel_tam_blocos(jj) == 1
                        fprintf('Grupo %.0f: posi��o %.0f a %.0f para %.6f (outlier)\n', jj,nivel_ini(jj),nivel_fim(jj));
                        outlier=nivel_adcp(nivel_fim(jj)+1);

                        nivel_adcp(nivel_fim(jj)+1)= ( (nivel_adcp(nivel_fim(jj)+2)) + (nivel_adcp(nivel_fim(jj))) )/2;
                        
                        outlier_corrigido = nivel_adcp(nivel_fim(jj)+1);
                        fprintf('Outlier corrigido: de %.6f para %.6f\n', outlier,outlier_corrigido);
                        
                        outliers_unicos_nivel(conta_outliers_nivel)=nivel_fim(jj)+1;
                        conta_outliers_nivel = conta_outliers_nivel + 1;
                    else
                % Para 3 ou mais outliers consecutivos, substitui por  
                % interpola��o linear:
                        fprintf('Grupo %.0f: posi��o %.0f a %.0f para %.6f (outlier)\n', jj,nivel_ini(jj),nivel_fim(jj));
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

% Subtrai o valor de 100 da vari�vel do n�vel do mar trabalhada:
nivel_adcp_limpo=nivel_adcp-100;

%% Figuras:
% Figura 1: Compara��o do sinal original e do sinal limpo de n�vel do mar,
% em um bloco selecionado da s�rie temporal. A limpeza remove outliers 
% individuais detectados via normaliza��o da diferen�a temporal (z-score).
%
% A linha vermelha representa o dado original, e a azul o sinal corrigido.

% Define qual bloco ser� mostrado nos plots:
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
ylabel('N�vel (metros)');
title(['N�vel (metros) - Exemplo de Bloco de Dados Completos, Std: '...
    ,num2str(std (zscore_diff(indice_bloco_plot_ini:indice_bloco_plot_fim))),', Limiar de Outlier: ',num2str(limiar_corr_int_nivel_nao_nan),' ']);

% Figura 2: Diferen�a temporal entre pontos consecutivos da s�rie (diff).
% Essa an�lise evidencia as varia��es bruscas, auxiliando na detec��o 
% de outliers. Sinais suavizados devem apresentar diffs mais homog�neos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(2)
clf
hold
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim-1),diff(nivel_adcp_orig(indice_bloco_plot_ini:indice_bloco_plot_fim)),'r')
plot(tempo_total_vetorial(indice_bloco_plot_ini:indice_bloco_plot_fim-1),diff(nivel_adcp_limpo(indice_bloco_plot_ini:indice_bloco_plot_fim)))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferen�a do N�vel (metros)');
grid;
title(['Diff do N�vel (metros)']);

%% An�lises Quantitativas da Remo��o de Outliers:

outliers_nivel_corrigidos = unique(outliers_unicos_nivel);

% Porcentagem total de pontos de outliers em rela��o ao total de dados:
quantidade_unica_outliers_nivel = length(unique(outliers_unicos_nivel));
porcentagem_outliers_nivel = (((quantidade_unica_outliers_nivel))/ii);
fprintf('Porcentagem total de outliers do N�vel: %.6f\n', porcentagem_outliers_nivel);

% Estat�stica b�sica de antes e depois dos outliers:
% m�dia:
media_nivel_antes=mean(nivel_adcp_orig(1:ii-1));
media_nivel_depois=mean(nivel_adcp_limpo(1:ii));
fprintf('M�dia antes e depois, do N�vel: %.6f e %.6f\n', media_nivel_antes, media_nivel_depois);

% std:
std_nivel_antes=std(nivel_adcp_orig(1:ii));
std_nivel_depois=std(nivel_adcp_limpo(1:ii));
fprintf('STD antes e depois do N�vel: %.6f e %.6f\n', std_nivel_antes, std_nivel_depois);


figure(3)
clf
hold on
plot(tempo_total_vetorial(outliers_nivel_corrigidos), nivel_adcp_orig(outliers_nivel_corrigidos), 'r')
plot(tempo_total_vetorial(outliers_nivel_corrigidos), nivel_adcp_limpo(outliers_nivel_corrigidos), 'b')
title(['Outliers detectados'])

%% Salva as vari�veis

% Formato .mat:

%vetor com as datas em formato datenum:
vetor_datas_num=datenum(dados(:,3),dados(:,2),dados(:,1),dados(:,4),dados(:,5),dados(:,6)); 

save('nivel_adcp_limpo.mat','nivel_adcp_limpo','outliers_nivel_corrigidos','vetor_datas_num');

