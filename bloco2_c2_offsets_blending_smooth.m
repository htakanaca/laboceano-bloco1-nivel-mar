%
% Bloco 2 - Scripts de Processamento LabOceano
%
% Passo 2: Revisão de offsets gerados pela previsão de maré e blending com 
% suavização de offsets para as Correntes Marinhas.
%
% Aplicação: Dados de CORRENTES MARINHAS medidas pelo ADCP da Bóia BH07, 
% Baía de Guanabara, RJ - Brasil.
%
% Utiliza-se o pacote U-Tide de Codiga (2011) para preencher as falhas 
% com previsão de maré.
%
% Hatsue Takanaca de Decco, Abril/2025.
% Contribuições de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio da inteligência
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025.
% Gemini (Google AI), em junho de 2025 (comentários sobre "filter").
% A lógica foi construída a partir de instruções e ajustes
% fornecidos pela pesquisadora, garantindo coerência com os
% objetivos e critérios do estudo.
%
% A coautoria simbólica da IA é reconhecida no aspecto técnico,
% sem implicar autoria científica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% U-Tide de Codiga (2011):
% Copyright (c) 2017, Daniel L. Codiga — redistribuído conforme licença BSD.
%
% Dados de Correntes Marinhas na "superfície":
% - Frequência amostral: 5 minutos.
% - Período: 01/01/2020 às 00:00h a 31/12/2024 às 23:55h.
% - Colunas: 1  2   3   4  5  6   7   8
% - Formato: DD,MM,YYYY,HH,MM,SS, Direção em graus (Norte geográfico - 0º),
% Intensidade em nós.
%
% ATENÇÃO: 
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na variável abaixo "data_dir". Os dados
% devem estar no formato definido acima.
%
% 2) Sobre o formato das lacunas de dados:
% Os dados faltantes devem estar preenchidos com NaN!
% => se as falhas amostrais estiverem SEM DADO nas coluna 7 e 8 (ou em toda
% a linha), vai dar ERRO.
% => se as falhas amostrais estiverem preenchidas com 0 na coluna 7 e 8 (ou 
% em toda a linha), vai dar ERRO.
%
% ATENÇÃO:
% - Este script deve ser executado após o preenchimento das falhas
%   amostrais com o método harmônico (ex: U-Tide).
% - Os dados devem estar organizados com NaNs para as lacunas.
%

clear
clc
%% Abertura e Organização dos dados

% === CONFIGURAÇÃO DO USUÁRIO ===
% Defina aqui o caminho para o diretório onde estão os dados originais, que
% ainda contém falhas amostrais, para fins de comparação posterior:
data_dir = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Define o nome do arquivo de dados:
nome_arquivo = 'nomedoarquivo.mat'; % .mat, .txt, etc
arquivo = fullfile(data_dir, nome_arquivo);

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

% Defina aqui o caminho para o diretório onde está o arquivo da série de 
% previsão harmônica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m")
data_dir_b1n1 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Carrega a série de previsão harmônica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m"):
arquivo_b1n1 = fullfile(data_dir_b1n1, 'corr_adcp_comtide.mat');

% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n1, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATENÇÃO!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO NÃO ENCONTRADO!\n\n' ...
           'Verifique se o diretório está correto:\n  %s\n\n' ...
           'E se o nome do arquivo está correto:\n  %s\n\n'], ...
           data_dir_b1n1, arquivo_b1n1);
end

load(arquivo_b1n1);

%% Definição de parâmetros e variáveis
%
% Identificação dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de nível do mar em que a previsão de maré inserida
% gerou offsets.
%

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Marca as posições dos NaN:
marca_nan=isnan(dados(:,7));

% Adiciona um zero no final para facilitar a detecção de bordas de blocos 
% de NaN e evitar erro no cálculo de diferenças, garantindo vetor como 
% linha:
marca_nan(end+1)=0;
marca_nan=marca_nan';

% Calcula a diferença entre elementos consecutivos para identificar as 
% transições entre dados e NaNs:
% Onde diff = 1, começa uma falha; onde diff = -1, termina.
diff_marca_nan(1:length(marca_nan))=zeros;
diff_marca_nan(2:end)=diff(marca_nan);

% Ajuste para garantir que o primeiro elemento do vetor de diferenças 
% esteja corretamente inicializado:
% (Se a série começa com dado (e não NaN), é 0)
diff_marca_nan(1)=0;

% Localiza os índices onde começam os blocos de NaNs (falhas):
% O preenchimento do vetor ini_nan_index_global começa a partir da posição 
% 2, para evitar erros se a série começar com NaN.
xx=find(diff_marca_nan==1);
ini_nan_index_global(2:length(xx)+1)=xx;

%  Identifica os índices finais das falhas, ajustando para referenciar o 
% último índice de NaN antes do retorno aos dados válidos:
xx=find(diff_marca_nan==-1);
fim_nan_index_global(2:length(xx)+1)=xx-1;

%Calcula a duração de cada bloco de NaN (lacuna) detectada:
duracao_nan_index_global=fim_nan_index_global-ini_nan_index_global;

% Extrai a série de componente meridional de velocidade V para uma variável 
% direta:
u_sup_adcp=dados(:,8).*sind(dados(:,7));
v_sup_adcp=dados(:,8).*cosd(dados(:,7));

% Guarda uma cópia da previsão harmônica original para posterior 
% comparação com a versão suavizada:
u_sup_adcp_comtide_raw = u_sup_adcp_comtide; % salva versão sem blending
v_sup_adcp_comtide_raw = v_sup_adcp_comtide; % salva versão sem blending

%% Blending nas bordas das lacunas que foram preenchidas com previsão de maré
%
% Define quantos pontos serão usados em cada borda para realizar a 
% transição gradual entre observação e previsão, minimizando 
% descontinuidades:
n_blend = 2;

%
% U:
%
% Loop sobre todas as lacunas detectadas, começando da segunda posição, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Inclui a interpolação linear para preenchimento de falhas amostrais
    % com duração menor que 3 que não foram preenchidas com previsão
    % de maré (para economia computacional). Caso não hajam NaNs, será
    % aplicado o Blending diretamente.
    
    % Parâmetro zerado antes do teste de NaN. Se houver NaN, ele recebe
    % valor de 1 no próximo IF:
    correcao_nan = 0;
    zerou = 0;
    
    if(duracao_nan_index_global(ii)<=6)
        
        % Verifica se sobrou NaN no bloco original de falha amostral:
        yy = length(find(isnan(u_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)))==1));
        
        % Caso haja algum NaN, sera iniciada a interpolação linear:
        if yy >= 1
            
            % Interpolação linear:
            u_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)) = 0;

            pedaco = (u_sup_adcp_comtide(fim_nan_index_global(ii)+1) - u_sup_adcp_comtide(ini_nan_index_global(ii)-1)) /...
                (duracao_nan_index_global(ii) + 2 );

            contap = 0;

            for jj=1:duracao_nan_index_global(ii)+1

                u_sup_adcp_comtide(ini_nan_index_global(ii)+contap) = u_sup_adcp_comtide(ini_nan_index_global(ii) -1 + contap) + pedaco;

                fprintf('NaN corrigido: %.2f em %d\n', u_sup_adcp_comtide(ini_nan_index_global(ii)+contap), ini_nan_index_global(ii)+contap);                

                contap=contap+1;
                
                % Registra que corrigiu a falha amostral restante com
                % interpolação linear, para não entrar no loop do Blending
                % a seguir:
                correcao_nan = 1;
            end
        end
    end

    % Bloco de aplicação de Blending sobre os offsets
    
    % Somente fará o blending onde não restou falha amostral:
    if correcao_nan == 0
        % Índices da borda anterior e posterior:
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
        
        % Blending na borda final (após a lacuna de falha amostral)
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
        % Se houve valor zerado durante o Blending, ele é marcado com NaN
        % para posterior avaliação:
        if zerou == 1
            u_sup_adcp_comtide(idx_fim + xx) = NaN;
        end
    end
end


%
% V:
%
% Loop sobre todas as lacunas detectadas, começando da segunda posição, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Inclui a interpolação linear para preenchimento de falhas amostrais
    % com duração menor que 3 que não foram preenchidas com previsão
    % de maré (para economia computacional). Caso não hajam NaNs, será
    % aplicado o Blending diretamente.
    
    % Parâmetro zerado antes do teste de NaN. Se houver NaN, ele recebe
    % valor de 1 no próximo IF:
    correcao_nan = 0;
    zerou = 0;
    
    if(duracao_nan_index_global(ii)<=6)
        
        % Verifica se sobrou NaN no bloco original de falha amostral:
        yy = length(find(isnan(v_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)))==1));
        
        % Caso haja algum NaN, sera iniciada a interpolação linear:
        if yy >= 1
            
            % Interpolação linear:
            v_sup_adcp_comtide(ini_nan_index_global(ii):fim_nan_index_global(ii)) = 0;

            pedaco = (v_sup_adcp_comtide(fim_nan_index_global(ii)+1) - v_sup_adcp_comtide(ini_nan_index_global(ii)-1)) /...
                (duracao_nan_index_global(ii) + 2 );

            contap = 0;

            for jj=1:duracao_nan_index_global(ii)+1

                v_sup_adcp_comtide(ini_nan_index_global(ii)+contap) = v_sup_adcp_comtide(ini_nan_index_global(ii) -1 + contap) + pedaco;

                fprintf('NaN corrigido: %.2f em %d\n', v_sup_adcp_comtide(ini_nan_index_global(ii)+contap), ini_nan_index_global(ii)+contap);                
                
                contap=contap+1;
                
                % Registra que corrigiu a falha amostral restante com
                % interpolação linear, para não entrar no loop do Blending
                % a seguir:
                correcao_nan = 1;
            end
        end
    end

    % Bloco de aplicação de Blending sobre os offsets
    
    % Somente fará o blending onde não restou falha amostral:
    if correcao_nan == 0
        % Índices da borda anterior e posterior:
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
        
        % Blending na borda final (após a lacuna de falha amostral)
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
        % Se houve valor zerado durante o Blending, ele é marcado com NaN
        % para posterior avaliação:
        if zerou == 1
            v_sup_adcp_comtide(idx_fim + xx) = NaN;
        end
    end
end

%% Segunda suavização pós-blending para garantir suavização mais homogênea para as várias lacunas

%
% U:
% 
% Parâmetro: definição da largura da janela da média móvel (ímpar, 
% de preferência):
win_movmean = 3;

% Cópia da série após blending:
u_sup_adcp_suave = u_sup_adcp_comtide;  

for ii = 2:length(duracao_nan_index_global)
    
    % Índices da borda anterior e posterior:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suavização borda inicial:
    trecho_ini = u_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    % Define o filtro de suavização, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes são os termos que consideram a 
    % influência direta da entrada no resultado atual. São os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes são os termos que consideram 
    % a influência da saída anterior no resultado atual. Eles dão ao 
    % filtro uma "memória", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro é de resposta ao 
    % impulso finita (FIR), o que é um caso mais simples.
    a_coef = 1;
    media_ini = filter(b_coef, a_coef, trecho_ini);
    % Corrige o atraso do filtro causal
    u_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suavização borda final:
    trecho_fim = u_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    % Define o filtro de suavização, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes são os termos que consideram a 
    % influência direta da entrada no resultado atual. São os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes são os termos que consideram 
    % a influência da saída anterior no resultado atual. Eles dão ao 
    % filtro uma "memória", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro é de resposta ao 
    % impulso finita (FIR), o que é um caso mais simples.
    a_coef = 1;    
    media_fim = filter(b_coef, a_coef, trecho_fim);
    u_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end


%
% V:
%
% Parâmetro: definição da largura da janela da média móvel (ímpar, 
% de preferência):
win_movmean = 3;

% Cópia da série após blending:
v_sup_adcp_suave = v_sup_adcp_comtide;  

for ii = 2:length(duracao_nan_index_global)
    
    % Índices da borda anterior e posterior:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suavização borda inicial:
    trecho_ini = v_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    % Define o filtro de suavização, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes são os termos que consideram a 
    % influência direta da entrada no resultado atual. São os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes são os termos que consideram 
    % a influência da saída anterior no resultado atual. Eles dão ao 
    % filtro uma "memória", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro é de resposta ao 
    % impulso finita (FIR), o que é um caso mais simples.
    a_coef = 1;
    media_ini = filter(b_coef, a_coef, trecho_ini);
    % Corrige o atraso do filtro causal
    v_sup_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suavização borda final:
    trecho_fim = v_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    % Define o filtro de suavização, baseado em dois coeficientes:
    % Termos com b_coef (numerador): Estes são os termos que consideram a 
    % influência direta da entrada no resultado atual. São os termos que 
    % definem a "resposta de impulso" do filtro, ou seja, como ele reage 
    % a um "choque" na entrada.
    b_coef = ones(1, win_movmean)/win_movmean;
    % Termos com a_coef (denominador): Estes são os termos que consideram 
    % a influência da saída anterior no resultado atual. Eles dão ao 
    % filtro uma "memória", tornando-o um filtro de resposta ao impulso 
    % infinita (IIR). Se a for apenas [1], o filtro é de resposta ao 
    % impulso finita (FIR), o que é um caso mais simples.
    a_coef = 1;    
    media_fim = filter(b_coef, a_coef, trecho_fim);
    v_sup_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end


%% Salva as variáveis

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

% Sem cabeçalho:
% dlmwrite('nivel_adcp_suave.csv', dados_suavizados, 'delimiter', ',', 'precision', 6);

filename = 'corr_adcp_suave.csv';
fid = fopen(filename, 'w');

% Escreve o cabeçalho
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

%% Plotagem para inspeção visual
%
% --- Plots: original, previsão harmônica, e previsão suavizada ---
figure(1)
clf
hold on

% Sinal original (com NaNs)
plot(u_sup_adcp, 'k', 'DisplayName', 'Série original')

% Previsão harmônica antes do blending
plot(u_sup_adcp_comtide_raw, 'b', 'DisplayName', 'Previsão harmônica (raw)')

% Previsão harmônica suavizada (com blending)
plot(u_sup_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending')

% Previsão harmônica pós-suavização com blending:
plot(u_sup_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending e pós-suavização')

% Legenda e título
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suavização por blending')
xlabel('Tempo (índice)')
ylabel('Componente U de Velocidade (m/s)')
grid on
box on

% Lacuna para inspeção visual:
indice_lacuna_plot = 102;
% Zoom automático na primeira lacuna para inspeção de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])



figure(2)
clf
hold on

% Sinal original (com NaNs)
plot(v_sup_adcp, 'k', 'DisplayName', 'Série original')

% Previsão harmônica antes do blending
plot(v_sup_adcp_comtide_raw, 'b', 'DisplayName', 'Previsão harmônica (raw)')

% Previsão harmônica suavizada (com blending)
plot(v_sup_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending')

% Previsão harmônica pós-suavização com blending:
plot(v_sup_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending e pós-suavização')

% Legenda e título
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suavização por blending')
xlabel('Tempo (índice)')
ylabel('Componente V de Velocidade (m/s)')
grid on
box on

% Lacuna para inspeção visual:
indice_lacuna_plot = 102;
% Zoom automático na primeira lacuna para inspeção de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])
