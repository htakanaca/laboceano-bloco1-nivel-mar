%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 2: Revis�o de offsets gerados pela previs�o de mar� e blending 
% 
% Aplica��o: Dados de N�VEL DO MAR de ADCP da B�ia BH07, na Ba�a de 
% Guanabara.
%
% Este script realiza a identifica��o, an�lise e ajuste de offsets
% nos dados pr�-processados, aplicando blending e suaviza��o para
% garantir a continuidade e qualidade da s�rie temporal.
%
% Hatsue Takanaca de Decco, 30/05/2025.
%
% Contribui��es de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio da intelig�ncia
% artificial ChatGPT (OpenAI) e Grok(xAI), em maio de 2025.
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
% - Este script deve ser executado ap�s o preenchimento das falhas
%   amostrais com o m�todo harm�nico (ex: U-Tide).
% - Os dados devem estar organizados com NaNs para as lacunas.
%

clear
clc

%% Abertura e Organiza��o dos dados

% === CONFIGURA��O DO USU�RIO ===
% Defina aqui o nome do arquivo onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc
% Nome da s�rie de previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m"):
arquivo_b1n1 = fullfile(data_dir_b1n1, 'nivel_adcp_comtide.mat');



% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diret�rio onde o script est� localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diret�rio de dados em rela��o � pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);
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



% Defina aqui o caminho para o diret�rio onde est� o arquivo da s�rie de 
% previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_n1_gapfilling_tide_codiga2011.m")
data_dir_b1n1 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n1, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATEN��O!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO N�O ENCONTRADO!\n\n' ...
           'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
           'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
           data_dir_b1n1, arquivo_b1n1);
end

load(arquivo_b1n1);

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

%% Defini��o de par�metros e vari�veis
%
% Identifica��o dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de n�vel do mar em que a previs�o de mar� inserida
% gerou offsets.
%

% Identifica os pontos onde a s�rie apresenta lacunas (NaNs):
marca_nan=isnan(dados(:,7));

% Adiciona um zero no final para facilitar a detec��o de bordas de blocos 
% de NaN e evitar erro no c�lculo de diferen�as, garantindo vetor como 
% linha:
marca_nan(end+1)=0;
marca_nan=marca_nan';

% Calcula a diferen�a entre elementos consecutivos para identificar as 
% transi��es entre dados e NaNs:
% Onde diff = 1, come�a uma falha; onde diff = -1, termina.
diff_marca_nan(1:length(marca_nan))=zeros;
diff_marca_nan(2:end)=diff(marca_nan);

% Ajuste para garantir que o primeiro elemento do vetor de diferen�as 
% esteja corretamente inicializado:
% (Se a s�rie come�a com dado (e n�o NaN), � 0)
diff_marca_nan(1)=0;

% Localiza os �ndices onde come�am os blocos de NaNs (falhas):
% O preenchimento do vetor ini_nan_index_global come�a a partir da posi��o 
% 2, para evitar erros se a s�rie come�ar com NaN.
xx=find(diff_marca_nan==1);
ini_nan_index_global(2:length(xx)+1)=xx;

%  Identifica os �ndices finais das falhas, ajustando para referenciar o 
% �ltimo �ndice de NaN antes do retorno aos dados v�lidos:
xx=find(diff_marca_nan==-1);
fim_nan_index_global(2:length(xx)+1)=xx-1;

%Calcula a dura��o de cada bloco de NaN (lacuna) detectada:
duracao_nan_index_global=fim_nan_index_global-ini_nan_index_global;

% Extrai a s�rie de n�vel do mar original, da coluna 7, para uma vari�vel 
% direta:
nivel_adcp=dados(:,7);

% Guarda uma c�pia da previs�o harm�nica original para posterior 
% compara��o com a vers�o suavizada:
nivel_adcp_comtide_raw = nivel_adcp_comtide; 

%% Blending nas bordas das lacunas
%
% Define quantos pontos ser�o usados em cada borda para realizar a 
% transi��o gradual entre observa��o e previs�o, minimizando 
% descontinuidades:
n_blend = 3;


% Loop sobre todas as lacunas detectadas, come�ando da segunda posi��o, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    
    % Define �ndices de in�cio e fim da lacuna atual:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Blending na borda inicial (antes da lacuna)
    % Garante que h� dados suficientes antes da lacuna para aplicar o 
    % blending:
    if idx_ini - n_blend >= 1
        % Se houver dados suficientes antes da lacuna para aplicar o 
        % blending, separa borda_obs (dados imediatamente antes da lacuna) 
        % e borda_pred (dados previstos ap�s a lacuna):
        borda_obs = nivel_adcp_comtide(idx_ini - n_blend : idx_ini - 1);
        borda_pred = nivel_adcp_comtide(idx_ini : idx_ini + n_blend - 1);
        % Realiza interpola��o linear progressiva entre as bordas, 
        % suavizando a transi��o para evitar saltos abruptos:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_adcp_comtide(idx_ini - 1 + jj) = (1 - w) * borda_obs(jj) + w * borda_pred(jj);
        end
    end

    % Blending na borda final (ap�s a lacuna)
    % Garante que h� pontos suficientes ap�s a lacuna para aplicar o 
    % blending:
    if idx_fim + n_blend <= length(nivel_adcp_comtide)
        % Extrai bordas para suaviza��o: borda_pred (antes do fim da 
        % lacuna) e borda_obs (imediatamente ap�s a lacuna):
        borda_pred = nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim);
        borda_obs = nivel_adcp_comtide(idx_fim + 1 : idx_fim + n_blend);
        % Aplica blending progressivo na borda final, com mesma l�gica de 
        % suaviza��o linear:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_adcp_comtide(idx_fim - n_blend + jj) = (1 - w) * borda_pred(jj) + w * borda_obs(jj);
        end
    end
end

%% Segunda suaviza��o p�s-blending (para garantir suaviza��o mais homog�nea para as v�rias lacunas)

% Define largura da janela para aplicar m�dia m�vel ap�s o blending, 
% promovendo suaviza��o adicional e eliminando eventuais artefatos
% (�mpar de prefer�ncia):
win_movmean = 3;

% Cria c�pia da s�rie j� com blending, para aplicar a suaviza��o final 
% sem sobrescrever:
nivel_adcp_suave = nivel_adcp_comtide;  

% Aplica suaviza��o em todas as lacunas detectadas:
for ii = 2:length(duracao_nan_index_global)
    
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suaviza��o borda inicial
    % Seleciona o trecho inicial ap�s a lacuna e aplica filtro de 
    % m�dia m�vel:
    trecho_ini = nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    media_ini = filter(ones(1, win_movmean)/win_movmean, 1, trecho_ini);
    % Ajusta a sa�da do filtro para compensar o atraso introduzido pelo 
    % filtro causal:
    nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suaviza��o borda final
    % Repete o mesmo processo na borda final, garantindo transi��o 
    % suave e sem descontinuidades:
    trecho_fim = nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    media_fim = filter(ones(1, win_movmean)/win_movmean, 1, trecho_fim);
    nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end

%% Salva as vari�veis

% Formato .mat:
save ('nivel_adcp_suave.mat','nivel_adcp_suave');

% Formato .csv:
dados_suavizados = dados(1:tamanho_tempo_total,1:6);
dados_suavizados(:,7) = nivel_adcp_suave;

% Sem cabe�alho:
% dlmwrite('nivel_adcp_suave.csv', dados_suavizados, 'delimiter', ',', 'precision', 6);

filename = 'nivel_adcp_suave.csv';
fid = fopen(filename, 'w');

% Escreve o cabe�alho
fprintf(fid, 'DD;MM;YYYY;HH;MM;SS;Nivel(m)\n');

% Escreve os dados com separador ';' e 4 casas decimais
for i = 1:size(dados_suavizados,1)
    fprintf(fid, '%02d;%02d;%04d;%02d;%02d;%02d;%.4f\n', ...
        dados_suavizados(i,1), dados_suavizados(i,2), dados_suavizados(i,3), ...
        dados_suavizados(i,4), dados_suavizados(i,5), dados_suavizados(i,6), ...
        dados_suavizados(i,7));
end

fclose(fid);

%% Plotagem para inspe��o visual
%
% --- Plots: original, previs�o harm�nica, e previs�o suavizada ---

% Inicializa figura, limpando qualquer plot anterior:
figure(1)
clf
hold on

% Plota todas as s�ries relevantes, cada uma com cor distinta e legenda, 
% permitindo compara��o direta entre os diferentes est�gios do 
% processamento

% Sinal original (com NaNs):
plot(nivel_adcp, 'k', 'DisplayName', 'S�rie original')

% Previs�o harm�nica antes do blending:
plot(nivel_adcp_comtide_raw, 'b', 'DisplayName', 'Previs�o harm�nica (raw)')

% Previs�o harm�nica suavizada (com blending):
plot(nivel_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending')

% Previs�o harm�nica p�s-suaviza��o com blending:
plot(nivel_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending e p�s-suaviza��o')

% Legenda e t�tulo:
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suaviza��o por blending')
xlabel('Tempo (�ndice)')
ylabel('N�vel do mar (m)')
grid on
box on


% Define uma lacuna espec�fica para zoom e inspe��o detalhada da 
% qualidade do preenchimento:

% Dica: para inspecionar outra lacuna, basta mudar o valor de 'indice_lacuna_plot' 
% e rodar novamente este bloco de c�digo:
% =================================
indice_lacuna_plot = 9;
% Zoom autom�tico na primeira lacuna para inspe��o de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])
% =================================

% Sugest�o de comando para salvar a figura com qualidade alta para 
% relat�rios ou apresenta��es:
% print('nivel_mar_blending_zoom','-dpng','-r300')


