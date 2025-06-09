%
% Vers�o: 2.0-Optmized
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
% artificial ChatGPT (OpenAI) e Grok(xAI), em maio de 2025,
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
% - Este script deve ser executado ap�s o preenchimento das falhas
%   amostrais com o m�todo harm�nico (ex: U-Tide).
% - Os dados devem estar organizados com NaNs para as lacunas.
%

clear
clc

%% Abertura e Organiza��o dos dados

% === CONFIGURA��O DO USU�RIO ===
%
% INPUT:
% Defina aqui o nome do arquivo onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc
% Nome da s�rie de previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_n1_gapfilling_tide_codiga2011.m"):
nomedoarquivo_b1n1 = 'nivel_adcp_comtide.mat';
%
% OUTPUT:
% Nome do arquivo de output, com os dados preenchidos com previs�o de mar�
% e com os offsets com blending e suaviza��o, formato CSV):
filename_output_csv = './Dados/nivel_adcp_suave.csv';
% formato .mat:
filename_output_mat = './Dados/nivel_adcp_suave.mat';
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
arquivo_b1n1 = fullfile(data_dir, nomedoarquivo_b1n1);

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

% Leitura dos dados originais com lacunas preenchidas para aplicar o 
% blending:
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
           data_dir, nomedoarquivo_b1n1);
end

% Carrega direto para a vari�vel de mesmo nome:
load(arquivo_b1n1, 'nivel_adcp_comtide'); 
% "nivel_adcp_comtide" agora est� no workspace.

fprintf('Leitura dos arquivos feita com sucesso\n')

%% Defini��o de par�metros e vari�veis
%
% Identifica��o dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de n�vel do mar em que a previs�o de mar� inserida
% gerou offsets.
%

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

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

% Vetor de pesos de blending:
w = ((1:n_blend) / (n_blend + 1))'; 

% Loop sobre todas as lacunas detectadas, come�ando da segunda posi��o, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Define �ndices de in�cio e fim da lacuna atual:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    if idx_fim + n_blend == length(nivel_adcp_comtide)
        
        fprintf('Tentativa de blending al�m do fim da s�rie!\n')
        % Neste caso, o blending n�o � feita e os pontos em quest�o s�o
        % substitu�dos pelo �ltimo valor observado:
        nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim) = nivel_adcp_comtide(idx_ini-1);
        continue
    end

    if idx_ini == length(nivel_adcp_comtide)
        
        fprintf('Tentativa de blending o �ltimo ponto da s�rie!\n')
        % Neste caso, o blending n�o � feito e o ponto em quest�o �
        % substitu�do pelo �ltimo valor observado:
        nivel_adcp_comtide(idx_ini) = nivel_adcp_comtide(idx_ini-1);
        
        break
    end
    
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
        % suavizando a transi��o para evitar saltos abruptos.
        % Otimiza��o: Aplicar blending vetorizado, sem alterar o obs.
        nivel_adcp_comtide(idx_ini - n_blend : idx_ini - 1) = (1 - w) .* borda_obs + w.* borda_pred;
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
        % Otimiza��o: Aplicar blending vetorizado, sem alterar o obs.
        nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim) = (1 - w) .* borda_pred + w .* borda_obs;
    end
    
    fprintf('Blending no in�cio em %.0f\n',ii)
end

%% Suaviza��o p�s-blending (para garantir suaviza��o mais homog�nea para as v�rias lacunas)

% Define largura da janela para aplicar m�dia m�vel ap�s o blending, 
% promovendo suaviza��o adicional e eliminando eventuais artefatos
% (�mpar de prefer�ncia, M�NIMO = 3):
win_movmean = 3;
% Certifique-se que win_movmean � �mpar e >=3 como voc� comentou.
if mod(win_movmean,2) == 0 || win_movmean < 3
    error('win_movmean deve ser um n�mero �mpar maior ou igual a 3 para esta suaviza��o.');
end

% Cria c�pia da s�rie j� com blending, para aplicar a suaviza��o final 
% sem sobrescrever:
nivel_adcp_suave = nivel_adcp_comtide;  

% Aplica suaviza��o em todas as lacunas detectadas:
for ii = 2:length(duracao_nan_index_global)
    
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    if idx_ini == length(nivel_adcp_suave)-1
        
        fprintf('Tentativa de suavizar o pen�ltimo ponto da s�rie!\n')
        % Neste caso, a suaviza��o n�o � feita e os pontos em quest�o s�o
        % substitu�dos pelo �ltimo valor observado:
        nivel_adcp_suave(idx_ini:end) = nivel_adcp_suave(idx_ini-1);
        
        continue
    end
    
    if idx_ini == length(nivel_adcp_suave)
        
        fprintf('Tentativa de suavizar o �ltimo ponto da s�rie!\n')
        % Neste caso, a suaviza��o n�o � feita e o ponto em quest�o �
        % substitu�do pelo �ltimo valor observado:
        nivel_adcp_suave(idx_ini) = nivel_adcp_suave(idx_ini-1);
        
        break
    end

    % Suaviza��o borda inicial
    % Seleciona o trecho inicial ap�s a lacuna e aplica filtro de 
    % m�dia m�vel:
    trecho_ini = nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    media_ini = filter(ones(1, win_movmean)/win_movmean, 1, trecho_ini);
    % Ajusta a sa�da do filtro para compensar o atraso introduzido pelo 
    % filtro causal mantendo os primeiros win_movmean-1 pontos originais 
    % do trecho_ini (que s�o os pontos que o filtro causal ainda n�o "viu" 
    % o suficiente para calcular uma m�dia completa) e usando os pontos 
    % filtrados e est�veis (media_ini(win_movmean:end)) para o restante do 
    % trecho (Isso � uma forma de criar uma transi��o suave para a m�dia 
    % m�vel, evitando um "salto" ou distor��o abrupta no in�cio do trecho 
    % filtrado.):
    nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suaviza��o borda final
    % Repete o mesmo processo na borda final, garantindo transi��o 
    % suave e sem descontinuidades:
    trecho_fim = nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    media_fim = filter(ones(1, win_movmean)/win_movmean, 1, trecho_fim);
    nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
    
    fprintf('Suaviza��o no in�cio em %.0f\n',ii)
end

%% Salva as vari�veis

% Formato .mat:
fprintf('Salvando arquivo MAT...\n')

save (filename_output_mat,'nivel_adcp_suave');

% Formato .csv:

fprintf('Salvando arquivo CSV...\n')

dados_suavizados = dados(1:tamanho_tempo_total,1:6);
dados_suavizados(:,7) = nivel_adcp_suave;

% Assumindo que "dados_suavizados" � uma matriz num�rica de 7 colunas
% [DD,MO,YYYY,HH,MM,SS,Nivel(m)]

% Crie uma tabela a partir da sua matriz para aproveitar o writetable
% E defina os nomes das colunas (cabe�alho)
T = array2table(dados_suavizados, 'VariableNames', {'DD','MO','YYYY','HH','MM','SS','Nivel_m'});

% Salva a tabela no formato CSV:
writetable(T, filename_output_csv, ...
    'Delimiter', ';', ... % Seu delimitador � ponto e v�rgula
    'WriteVariableNames', true, ... % Escreve os nomes das vari�veis (cabe�alho)
    'QuoteStrings', false, ... % Evita aspas em volta dos n�meros, se n�o forem strings
    'FileType', 'text'); % Especifica que � um arquivo de texto


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

fprintf('Feito!\n')

