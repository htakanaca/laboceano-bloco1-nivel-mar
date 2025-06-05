%
% Bloco 2 - Scripts de Processamento LabOceano
%
% Passo 2: Revis�o de offsets gerados pela previs�o de mar� e blending com 
% suaviza��o de offsets para as Correntes Marinhas.
%
% Aplica��o: Dados de CORRENTES MARINHAS medidas pelo ADCP da B�ia BH07, 
% Ba�a de Guanabara, RJ - Brasil.
%
% Utiliza-se o pacote U-Tide de Codiga (2011) para preencher as falhas 
% com previs�o de mar�.
%
% Hatsue Takanaca de Decco, Abril/2025.
% Contribui��es de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio da intelig�ncia
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025.
% Gemini (Google AI), em junho de 2025 (coment�rios sobre "filter").
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica da IA � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% U-Tide de Codiga (2011):
% Copyright (c) 2017, Daniel L. Codiga � redistribu�do conforme licen�a BSD.
%
% Dados de Correntes Marinhas na "superf�cie":
% - Frequ�ncia amostral: 5 minutos.
% - Per�odo: 01/01/2020 �s 00:00h a 31/12/2024 �s 23:55h.
% - Colunas: 1  2   3   4  5  6   7   8
% - Formato: DD,MM,YYYY,HH,MM,SS, Dire��o em graus (Norte geogr�fico - 0�),
% Intensidade em n�s.
%
% ATEN��O: 
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na vari�vel abaixo "data_dir". Os dados
% devem estar no formato definido acima.
%
% 2) Sobre o formato das lacunas de dados:
% Os dados faltantes devem estar preenchidos com NaN!
% => se as falhas amostrais estiverem SEM DADO nas coluna 7 e 8 (ou em toda
% a linha), vai dar ERRO.
% => se as falhas amostrais estiverem preenchidas com 0 na coluna 7 e 8 (ou 
% em toda a linha), vai dar ERRO.
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

% Defina aqui o caminho para o diret�rio onde est� o arquivo da s�rie de 
% previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m")
data_dir_b1n1 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Carrega a s�rie de previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m"):
arquivo_b1n1 = fullfile(data_dir_b1n1, 'corr_adcp_comtide.mat');

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

%% Defini��o de par�metros e vari�veis
%
% Identifica��o dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de n�vel do mar em que a previs�o de mar� inserida
% gerou offsets.
%

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Marca as posi��es dos NaN:
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

% Extrai a s�rie de componente meridional de velocidade V para uma vari�vel 
% direta:
u_sup_adcp=dados(:,8).*sind(dados(:,7));
v_sup_adcp=dados(:,8).*cosd(dados(:,7));

% Guarda uma c�pia da previs�o harm�nica original para posterior 
% compara��o com a vers�o suavizada:
u_sup_adcp_comtide_raw = u_sup_adcp_comtide; % salva vers�o sem blending
v_sup_adcp_comtide_raw = v_sup_adcp_comtide; % salva vers�o sem blending

%% Blending nas bordas das lacunas que foram preenchidas com previs�o de mar�
%
% Define quantos pontos ser�o usados em cada borda para realizar a 
% transi��o gradual entre observa��o e previs�o, minimizando 
% descontinuidades:
n_blend = 2;

%
% U:
%
% Loop sobre todas as lacunas detectadas, come�ando da segunda posi��o, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Inclui a interpola��o linear para preenchimento de falhas amostrais
    % com dura��o menor que 3 que n�o foram preenchidas com previs�o
    % de mar� (para economia computacional). Caso n�o hajam NaNs, ser�
    % aplicado o Blending diretamente.
    
    % Par�metro zerado antes do teste de NaN. Se houver NaN, ele recebe
    % valor de 1 no pr�ximo IF:
    correcao_nan = 0;
    zerou = 0;
    
    if(duracao_nan_index_global(ii)<=6)
        
        % Verifica se sobrou NaN no bloco original de falha amostral:
        yy = length(find(isnan(u_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)))==1));
        
        % Caso haja algum NaN, sera iniciada a interpola��o linear:
        if yy >= 1
            
            % Interpola��o linear:
            u_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)) = 0;

            pedaco = (u_sup_adcp_comtide(fim_nan_index_global(ii)+1) - u_sup_adcp_comtide(ini_nan_index_global(ii)-1)) /...
                (duracao_nan_index_global(ii) + 2 );

            contap = 0;

            for jj=1:duracao_nan_index_global(ii)+1

                u_sup_adcp_comtide(ini_nan_index_global(ii)+contap) = u_sup_adcp_comtide(ini_nan_index_global(ii) -1 + contap) + pedaco;

                fprintf('NaN corrigido: %.2f em %d\n', u_sup_adcp_comtide(ini_nan_index_global(ii)+contap), ini_nan_index_global(ii)+contap);                

                contap=contap+1;
                
                % Registra que corrigiu a falha amostral restante com
                % interpola��o linear, para n�o entrar no loop do Blending
                % a seguir:
                correcao_nan = 1;
            end
        end
    end

    % Bloco de aplica��o de Blending sobre os offsets
    
    % Somente far� o blending onde n�o restou falha amostral:
    if correcao_nan == 0
        % �ndices da borda anterior e posterior:
        idx_ini = ini_nan_index_global(ii);
        idx_fim = fim_nan_index_global(ii);
        
        % Blending na borda inicial (antes da lacuna de falha amostral)
        if idx_ini - n_blend >= 1
            borda_obs = u_sup_adcp_comtide(idx_ini - n_blend : idx_ini - 1);
            borda_pred = u_sup_adcp_comtide(idx_ini : idx_ini + n_blend - 1);
            for jj = 1:n_blend
                % Define um fator-rampa (w) para aplicar o blending ao 
                % longo dos pontos definidos anteriormente por n_blend:
                w = jj / (n_blend + 1);
                u_sup_adcp_comtide(idx_ini - 1 + jj) = (1 - w) * borda_obs(jj) + w * borda_pred(jj);
            end
        end
        
        % Blending na borda final (ap�s a lacuna de falha amostral)
        if(duracao_nan_index_global(ii)>=1)
            if idx_fim + n_blend <= length(u_sup_adcp_comtide)
                borda_pred = u_sup_adcp_comtide(idx_fim - n_blend + 1 : idx_fim);
                
                xx = find(isnan(u_sup_adcp_comtide(idx_fim + 1 : idx_fim + n_blend)));
                if xx > 0
                    u_sup_adcp_comtide(idx_fim + xx) = 0;
                    % Registra que zerou o valor para ser avaliado
                    % posteriormente:
                    zerou = 1;
                end
                
                borda_obs = u_sup_adcp_comtide(idx_fim + 1 : idx_fim + n_blend);
                for jj = 1:n_blend
                    % Define um fator-rampa (w) para aplicar o blending ao 
                    % longo dos pontos definidos anteriormente por n_blend:
                    w = jj / (n_blend + 1);
                    u_sup_adcp_comtide(idx_fim - n_blend + jj) = (1 - w) * borda_pred(jj) + w * borda_obs(jj);
                end
            end
        end
        % Se houve valor zerado durante o Blending, ele � marcado com NaN
        % para posterior avalia��o:
        if zerou == 1
            u_sup_adcp_comtide(idx_fim + xx) = NaN;
        end
    end
end


%
% V:
%
% Loop sobre todas as lacunas detectadas, come�ando da segunda posi��o, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Inclui a interpola��o linear para preenchimento de falhas amostrais
    % com dura��o menor que 3 que n�o foram preenchidas com previs�o
    % de mar� (para economia computacional). Caso n�o hajam NaNs, ser�
    % aplicado o Blending diretamente.
    
    % Par�metro zerado antes do teste de NaN. Se houver NaN, ele recebe
    % valor de 1 no pr�ximo IF:
    correcao_nan = 0;
    zerou = 0;
    
    if(duracao_nan_index_global(ii)<=6)
        
        % Verifica se sobrou NaN no bloco original de falha amostral:
        yy = length(find(isnan(v_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)))==1));
        
        % Caso haja algum NaN, sera iniciada a interpola��o linear:
        if yy >= 1
            
            % Interpola��o linear:
            v_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)) = 0;

            pedaco = (v_sup_adcp_comtide(fim_nan_index_global(ii)+1) - v_sup_adcp_comtide(ini_nan_index_global(ii)-1)) /...
                (duracao_nan_index_global(ii) + 2 );

            contap = 0;

            for jj=1:duracao_nan_index_global(ii)+1

                v_sup_adcp_comtide(ini_nan_index_global(ii)+contap) = v_sup_adcp_comtide(ini_nan_index_global(ii) -1 + contap) + pedaco;

                fprintf('NaN corrigido: %.2f em %d\n', v_sup_adcp_comtide(ini_nan_index_global(ii)+contap), ini_nan_index_global(ii)+contap);                
                
                contap=contap+1;
                
                % Registra que corrigiu a falha amostral restante com
                % interpola��o linear, para n�o entrar no loop do Blending
                % a seguir:
                correcao_nan = 1;
            end
        end
    end

    % Bloco de aplica��o de Blending sobre os offsets
    
    % Somente far� o blending onde n�o restou falha amostral:
    if correcao_nan == 0
        % �ndices da borda anterior e posterior:
        idx_ini = ini_nan_index_global(ii);
        idx_fim = fim_nan_index_global(ii);
        
        % Blending na borda inicial (antes da lacuna de falha amostral)
        if idx_ini - n_blend >= 1
            borda_obs = v_sup_adcp_comtide(idx_ini - n_blend : idx_ini - 1);
            borda_pred = v_sup_adcp_comtide(idx_ini : idx_ini + n_blend - 1);
            for jj = 1:n_blend
                % Define um fator-rampa (w) para aplicar o blending ao 
                % longo dos pontos definidos anteriormente por n_blend:
                w = jj / (n_blend + 1);
                v_sup_adcp_comtide(idx_ini - 1 + jj) = (1 - w) * borda_obs(jj) + w * borda_pred(jj);
            end
        end
        
        % Blending na borda final (ap�s a lacuna de falha amostral)
        if(duracao_nan_index_global(ii)>=1)
            if idx_fim + n_blend <= length(v_sup_adcp_comtide)
                borda_pred = v_sup_adcp_comtide(idx_fim - n_blend + 1 : idx_fim);
                
                xx = find(isnan(v_sup_adcp_comtide(idx_fim + 1 : idx_fim + n_blend)));
                if xx > 0
                    v_sup_adcp_comtide(idx_fim + xx) = 0;
                    % Registra que zerou o valor para ser avaliado
                    % posteriormente:
                    zerou = 1;
                end
                
                borda_obs = v_sup_adcp_comtide(idx_fim + 1 : idx_fim + n_blend);
                for jj = 1:n_blend
                    % Define um fator-rampa (w) para aplicar o blending ao 
                    % longo dos pontos definidos anteriormente por n_blend:
                    w = jj / (n_blend + 1);
                    v_sup_adcp_comtide(idx_fim - n_blend + jj) = (1 - w) * borda_pred(jj) + w * borda_obs(jj);
                end
            end
        end
        % Se houve valor zerado durante o Blending, ele � marcado com NaN
        % para posterior avalia��o:
        if zerou == 1
            v_sup_adcp_comtide(idx_fim + xx) = NaN;
        end
    end
end

%% Segunda suaviza��o p�s-blending para garantir suaviza��o mais homog�nea para as v�rias lacunas

%
% U:
% 
% Par�metro: defini��o da largura da janela da m�dia m�vel (�mpar, 
% de prefer�ncia):
win_movmean = 3;

% C�pia da s�rie ap�s blending:
u_sup_adcp_suave = u_sup_adcp_comtide;  

for ii = 2:length(duracao_nan_index_global)
    
    % �ndices da borda anterior e posterior:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suaviza��o borda inicial:
    trecho_ini = u_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    % Define o filtro de suaviza��o, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes s�o os termos que consideram a 
    % influ�ncia direta da entrada no resultado atual. S�o os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes s�o os termos que consideram 
    % a influ�ncia da sa�da anterior no resultado atual. Eles d�o ao 
    % filtro uma "mem�ria", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro � de resposta ao 
    % impulso finita (FIR), o que � um caso mais simples.
    a_coef = 1;
    media_ini = filter(b_coef, a_coef, trecho_ini);
    % Corrige o atraso do filtro causal
    u_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suaviza��o borda final:
    trecho_fim = u_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    % Define o filtro de suaviza��o, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes s�o os termos que consideram a 
    % influ�ncia direta da entrada no resultado atual. S�o os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes s�o os termos que consideram 
    % a influ�ncia da sa�da anterior no resultado atual. Eles d�o ao 
    % filtro uma "mem�ria", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro � de resposta ao 
    % impulso finita (FIR), o que � um caso mais simples.
    a_coef = 1;    
    media_fim = filter(b_coef, a_coef, trecho_fim);
    u_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end


%
% V:
%
% Par�metro: defini��o da largura da janela da m�dia m�vel (�mpar, 
% de prefer�ncia):
win_movmean = 3;

% C�pia da s�rie ap�s blending:
v_sup_adcp_suave = v_sup_adcp_comtide;  

for ii = 2:length(duracao_nan_index_global)
    
    % �ndices da borda anterior e posterior:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suaviza��o borda inicial:
    trecho_ini = v_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    % Define o filtro de suaviza��o, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes s�o os termos que consideram a 
    % influ�ncia direta da entrada no resultado atual. S�o os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes s�o os termos que consideram 
    % a influ�ncia da sa�da anterior no resultado atual. Eles d�o ao 
    % filtro uma "mem�ria", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro � de resposta ao 
    % impulso finita (FIR), o que � um caso mais simples.
    a_coef = 1;
    media_ini = filter(b_coef, a_coef, trecho_ini);
    % Corrige o atraso do filtro causal
    v_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suaviza��o borda final:
    trecho_fim = v_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    % Define o filtro de suaviza��o, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes s�o os termos que consideram a 
    % influ�ncia direta da entrada no resultado atual. S�o os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes s�o os termos que consideram 
    % a influ�ncia da sa�da anterior no resultado atual. Eles d�o ao 
    % filtro uma "mem�ria", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro � de resposta ao 
    % impulso finita (FIR), o que � um caso mais simples.
    a_coef = 1;    
    media_fim = filter(b_coef, a_coef, trecho_fim);
    v_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end


%% Salva as vari�veis

% Formato .mat:
save ('corr_adcp_suave.mat','corr_adcp_suave');

u_sup_adcp=dados(:,8).*sind(dados(:,7));
v_sup_adcp=dados(:,8).*cosd(dados(:,7));

mag_sup_adcp_comtide= sqrt((u_sup_adcp_comtide.^2)+(v_sup_adcp_comtide.^2));

direcao = atan2(v_sup_adcp_comtide,u_sup_adcp_comtide);
dir_sup_adcp_comtide = rad2deg(mod((pi/2 - direcao), 2*pi));

% Formato .csv:
dados_suavizados = dados(1:tamanho_tempo_total,1:6);
dados_preenchidos(:,7) = dir_sup_adcp_comtide;
dados_preenchidos(:,8) = mag_sup_adcp_comtide;

% Sem cabe�alho:
% dlmwrite('nivel_adcp_suave.csv', dados_suavizados, 'delimiter', ',', 'precision', 6);

filename = 'corr_adcp_suave.csv';
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

% Se quiser salvar:
% print('u_sup_mar_blending_zoom','-dpng','-r300')

nome_arquivo_out = 'corr_sup_adcp_comtide_posblending.mat';
save(nome_arquivo_out,'u_sup_adcp_comtide','v_sup_adcp_comtide','dados_suavizados');

%% Plotagem para inspe��o visual
%
% --- Plots: original, previs�o harm�nica, e previs�o suavizada ---
figure(1)
clf
hold on

% Sinal original (com NaNs)
plot(u_sup_adcp, 'k', 'DisplayName', 'S�rie original')

% Previs�o harm�nica antes do blending
plot(u_sup_adcp_comtide_raw, 'b', 'DisplayName', 'Previs�o harm�nica (raw)')

% Previs�o harm�nica suavizada (com blending)
plot(u_sup_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending')

% Previs�o harm�nica p�s-suaviza��o com blending:
plot(u_sup_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending e p�s-suaviza��o')

% Legenda e t�tulo
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suaviza��o por blending')
xlabel('Tempo (�ndice)')
ylabel('Componente U de Velocidade (m/s)')
grid on
box on

% Lacuna para inspe��o visual:
indice_lacuna_plot = 102;
% Zoom autom�tico na primeira lacuna para inspe��o de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])



figure(2)
clf
hold on

% Sinal original (com NaNs)
plot(v_sup_adcp, 'k', 'DisplayName', 'S�rie original')

% Previs�o harm�nica antes do blending
plot(v_sup_adcp_comtide_raw, 'b', 'DisplayName', 'Previs�o harm�nica (raw)')

% Previs�o harm�nica suavizada (com blending)
plot(v_sup_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending')

% Previs�o harm�nica p�s-suaviza��o com blending:
plot(v_sup_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending e p�s-suaviza��o')

% Legenda e t�tulo
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suaviza��o por blending')
xlabel('Tempo (�ndice)')
ylabel('Componente V de Velocidade (m/s)')
grid on
box on

% Lacuna para inspe��o visual:
indice_lacuna_plot = 102;
% Zoom autom�tico na primeira lacuna para inspe��o de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])
