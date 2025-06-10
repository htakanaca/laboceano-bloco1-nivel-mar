%
% Vers�o: 2.0-Optmized
%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 3: Detec��o e Substitui��o de Outliers dos dados, ap�s o
% preenchimento de falhas.
%
% Este script utiliza a FUN��O "limpa_outliers.m" que pode ser baixada em:
% https://github.com/htakanaca/AI-Assisted-Learning/blob/main/Matlab/Gemini/limpar_outliers.m
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
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio e junho de 2025,
% e Gemini (Gooogle AI) em junho de 2025.
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica da IA � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
%
% Resposit�rio (em desenvolvimento) de suporte did�tico por IA para
% conte�dos relacionados ao processamento de dados em:
% https://github.com/htakanaca/AI-Assisted-Learning
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
% Defina aqui o nome do arquivo onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc
% Nome da s�rie de previs�o harm�nica previamente ajustada com o U-Tide
% (salva pelo script "bloco1_n2_offsets_blending_smooth.m"):
nomedoarquivo_b1n2 = 'nivel_adcp_suave.mat';
%
% OUTPUT:
% Nome do arquivo de output, com os dados preenchidos com previs�o de mar�
% e com os offsets com blending e suaviza��o, formato CSV):
filename_output_csv = './Dados/nivel_adcp_limpo.csv';
% formato .mat:
filename_output_mat = './Dados/nivel_adcp_limpo.mat';
%
% === FIM DA CONFIGURA��O DO USU�RIO ===


% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diret�rio onde o script est� localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diret�rio de dados em rela��o � pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);
% Nome da s�rie de previs�o harm�nica previamente ajustada com o U-Tide
% (salva pelo script "bloco1_n2_offsets_blending_smooth.m"):
arquivo_b1n2 = fullfile(data_dir, nomedoarquivo_b1n2);

% Leitura dos dados originais para refer�ncia:
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
        data_dir, nomedoarquivo);
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
        
        % Otimiza��o: Carrega para uma struct e acessa o campo
        data_struct = load(arquivo, nome_var);
        dados = data_struct.(nome_var); % Acessa a vari�vel pelo nome
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz num�rica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo n�o suportado.');
end

% Leitura dos dados originais com lacunas preenchidas e com blending/
% suavizados:
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
        data_dir, nomedoarquivo_b1n2);
end

% Carrega direto para a vari�vel de mesmo nome:
load(arquivo_b1n2, 'nivel_adcp_suave');
% "nivel_adcp_suave" agora est� no workspace.

fprintf('Leitura dos arquivos feita com sucesso\n')


%% Defini��o de par�metros e vari�veis auxiliares:

% Renomeia os dados de n�vel do mar em um vetor separado:
nivel_adcp_orig = dados(:,7);

% Cria a vari�vel de trabalho dos outliers:
nivel_adcp = nivel_adcp_suave;

% Define o fator limiar de varia��o, acima do qual um ponto ser�
% considerado outlier:
fator_limiar = 5;

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de refer�ncia):
tempo_total_vetorial = 1:tamanho_tempo_total;

%% Detec��o e substitui��o de Outliers:
%
% Explica��o sobre o m�todo para entendimento das vari�veis a seguir:
%
% A substitui��o de outliers � feita utilizando uma fun��o criada para este
% fim. Nela, a s�rie � transformada em primeira derivada, pois a defini��o
% de Outlier � dada como uma varia��o brusca no n�vel do mar, provavelmente
% causada por sinais esp�rios ou ondas geradas por passagens de embarca��o
% pr�ximo ao local de medi��o do n�vel do mar pelo ADCP.
% A seguir, � calculada a medida estat�stica Z-score, com o qual � poss�vel
% definir o quanto a varia��o de n�vel do mar se distancia do desvio padr�o
% da s�rie, dando robustez estat�stica � an�lise. Uma explica��o sobre o 
% Z-score com abordagem mais did�tica, gerada em colabora��o com o Gemini 
% - modelo de linguagem da Google, pode ser encontrada em:
%   https://github.com/htakanaca/AI-Assisted-Learning/blob/main/Z-score-content/Gemini/zscore_explicacao-ptbr.md
% 
% Os Outliers s�o buscados ao longo de toda a s�rie e testados contra o
% "fator_limiar". Os elementos da s�rie identificados como Outliers s�o 
% substitu�dos por um valor m�dio entre os valores vizinhos.
%

fprintf('\nIniciando detec��o e substitui��o de outliers...\n');

% Defini��o do m�todo de interpola��o usado na fun��o de substitui��o de
% outliers:
% Escolha um dos m�todos:
% 'linear', 'spline', 'pchip', 'nearest', 'next', 'previous'
metodo_interp = ['linear'];

[nivel_adcp_limpo,pontos_outliers_corrigidos] = limpar_outliers(nivel_adcp, fator_limiar,metodo_interp);

%% Figuras:
% Figura 1: Compara��o do sinal original e do sinal limpo de n�vel do mar,
% em um bloco selecionado da s�rie temporal. A limpeza remove outliers
% individuais detectados via normaliza��o da diferen�a temporal (z-score).
%
% A linha vermelha representa o dado original, e a azul o sinal corrigido.

% Define qual bloco ser� mostrado nos plots:
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
ylabel('N�vel (metros)');
title(['N�vel (metros) - Exemplo de Bloco de Dados Completos, Limiar de Outlier: ',num2str(fator_limiar),' ']);

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

figure(3)
clf
hold on
plot(tempo_total_vetorial(pontos_outliers_corrigidos), nivel_adcp_orig(pontos_outliers_corrigidos), 'r')
plot(tempo_total_vetorial(pontos_outliers_corrigidos), nivel_adcp_limpo(pontos_outliers_corrigidos), 'b')
title(['Outliers detectados'])

%% An�lises Quantitativas da Remo��o de Outliers:

% >> COMENT�RIO GEMINI: C�lculo simplificado de estat�sticas.
% Porcentagem total de pontos de outliers em rela��o ao total de dados:
quantidade_outliers_nivel = length(pontos_outliers_corrigidos);
porcentagem_outliers_nivel = (quantidade_outliers_nivel*100)/tamanho_tempo_total;
fprintf('\n--- Estat�sticas da Limpeza ---\n');
fprintf('Total de pontos na s�rie: %d\n', tamanho_tempo_total);
fprintf('Total de outliers corrigidos: %d\n', quantidade_outliers_nivel);
fprintf('Porcentagem de outliers na s�rie: %.4f %%\n', porcentagem_outliers_nivel);

% Estat�stica b�sica de antes e depois dos outliers:
% zera a s�rie original onde tinha falha amostral apenas para estimar a
% m�dia e std originais da s�rie "bruta":
nivel_adcp_orig (isnan(nivel_adcp_orig)) = 0;
fprintf('M�dia antes: %.6f | M�dia depois: %.6f\n', mean(nivel_adcp_orig), mean(nivel_adcp_limpo));
fprintf('STD antes:   %.6f | STD depois:   %.6f\n', std(nivel_adcp_orig), std(nivel_adcp_limpo));
fprintf('--------------------------------\n');

%% Salva as vari�veis

% Formato .mat:
fprintf('Salvando arquivo MAT...\n')

save (filename_output_mat,'nivel_adcp_limpo','pontos_outliers_corrigidos');

% Formato .csv:
fprintf('Salvando arquivo CSV...\n')

dados_limpos = dados(1:tamanho_tempo_total,1:6);
dados_limpos(:,7) = nivel_adcp_limpo;

% Assumindo que 'dados_preenchidos' � uma matriz num�rica de 7 colunas
% [DD,MO,YYYY,HH,MM,SS,Nivel(m)]

% Crie uma tabela a partir da sua matriz para aproveitar o writetable
% E defina os nomes das colunas (cabe�alho)
T = array2table(dados_limpos, 'VariableNames', {'DD','MO','YYYY','HH','MM','SS','Nivel_m'});

% Salva a tabela no formato CSV:
writetable(T, filename_output_csv, ...
    'Delimiter', ';', ... % Seu delimitador � ponto e v�rgula
    'WriteVariableNames', true, ... % Escreve os nomes das vari�veis (cabe�alho)
    'QuoteStrings', false, ... % Evita aspas em volta dos n�meros, se n�o forem strings
    'FileType', 'text'); % Especifica que � um arquivo de texto

fprintf('Feito!\n')
