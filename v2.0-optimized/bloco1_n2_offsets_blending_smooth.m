%
% Versão: 2.0-Optmized
%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 2: Revisão de offsets gerados pela previsão de maré e blending 
% 
% Aplicação: Dados de NÌVEL DO MAR de ADCP da Bóia BH07, na Baía de 
% Guanabara.
%
% Este script realiza a identificação, análise e ajuste de offsets
% nos dados pré-processados, aplicando blending e suavização para
% garantir a continuidade e qualidade da série temporal.
%
% Hatsue Takanaca de Decco, 30/05/2025.
%
% Contribuições de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio da inteligência
% artificial ChatGPT (OpenAI) e Grok(xAI), em maio de 2025,
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
% - Este script deve ser executado após o preenchimento das falhas
%   amostrais com o método harmônico (ex: U-Tide).
% - Os dados devem estar organizados com NaNs para as lacunas.
%

clear
clc

%% Abertura e Organização dos dados

% === CONFIGURAÇÃO DO USUÁRIO ===
%
% INPUT:
% Defina aqui o nome do arquivo onde estão os dados originais, que
% ainda contém falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc
% Nome da série de previsão harmônica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_n1_gapfilling_tide_codiga2011.m"):
nomedoarquivo_b1n1 = 'nivel_adcp_comtide.mat';
%
% OUTPUT:
% Nome do arquivo de output, com os dados preenchidos com previsão de maré
% e com os offsets com blending e suavização, formato CSV):
filename_output_csv = './Dados/nivel_adcp_suave.csv';
% formato .mat:
filename_output_mat = './Dados/nivel_adcp_suave.mat';
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
arquivo_b1n1 = fullfile(data_dir, nomedoarquivo_b1n1);

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

% Leitura dos dados originais com lacunas preenchidas para aplicar o 
% blending:
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
           data_dir, nomedoarquivo_b1n1);
end

% Carrega direto para a variável de mesmo nome:
load(arquivo_b1n1, 'nivel_adcp_comtide'); 
% "nivel_adcp_comtide" agora está no workspace.

fprintf('Leitura dos arquivos feita com sucesso\n')

%% Definição de parâmetros e variáveis
%
% Identificação dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de nível do mar em que a previsão de maré inserida
% gerou offsets.
%

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Identifica os pontos onde a série apresenta lacunas (NaNs):
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

% Extrai a série de nível do mar original, da coluna 7, para uma variável 
% direta:
nivel_adcp=dados(:,7);

% Guarda uma cópia da previsão harmônica original para posterior 
% comparação com a versão suavizada:
nivel_adcp_comtide_raw = nivel_adcp_comtide; 

%% Blending nas bordas das lacunas
%
% Define quantos pontos serão usados em cada borda para realizar a 
% transição gradual entre observação e previsão, minimizando 
% descontinuidades:
n_blend = 3;

% Vetor de pesos de blending:
w = ((1:n_blend) / (n_blend + 1))'; 

% Loop sobre todas as lacunas detectadas, começando da segunda posição, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    % Define índices de início e fim da lacuna atual:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    if idx_fim + n_blend == length(nivel_adcp_comtide)
        
        fprintf('Tentativa de blending além do fim da série!\n')
        % Neste caso, o blending não é feita e os pontos em questão são
        % substituídos pelo último valor observado:
        nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim) = nivel_adcp_comtide(idx_ini-1);
        continue
    end

    if idx_ini == length(nivel_adcp_comtide)
        
        fprintf('Tentativa de blending o último ponto da série!\n')
        % Neste caso, o blending não é feito e o ponto em questão é
        % substituído pelo último valor observado:
        nivel_adcp_comtide(idx_ini) = nivel_adcp_comtide(idx_ini-1);
        
        break
    end
    
    % Blending na borda inicial (antes da lacuna)
    % Garante que há dados suficientes antes da lacuna para aplicar o 
    % blending:
    if idx_ini - n_blend >= 1
        % Se houver dados suficientes antes da lacuna para aplicar o 
        % blending, separa borda_obs (dados imediatamente antes da lacuna) 
        % e borda_pred (dados previstos após a lacuna):
        borda_obs = nivel_adcp_comtide(idx_ini - n_blend : idx_ini - 1);
        borda_pred = nivel_adcp_comtide(idx_ini : idx_ini + n_blend - 1);
        % Realiza interpolação linear progressiva entre as bordas, 
        % suavizando a transição para evitar saltos abruptos.
        % Otimização: Aplicar blending vetorizado, sem alterar o obs.
        nivel_adcp_comtide(idx_ini - n_blend : idx_ini - 1) = (1 - w) .* borda_obs + w.* borda_pred;
    end

    % Blending na borda final (após a lacuna)
    % Garante que há pontos suficientes após a lacuna para aplicar o 
    % blending:
    if idx_fim + n_blend <= length(nivel_adcp_comtide)
        % Extrai bordas para suavização: borda_pred (antes do fim da 
        % lacuna) e borda_obs (imediatamente após a lacuna):
        borda_pred = nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim);
        borda_obs = nivel_adcp_comtide(idx_fim + 1 : idx_fim + n_blend);
        % Aplica blending progressivo na borda final, com mesma lógica de 
        % suavização linear:
        % Otimização: Aplicar blending vetorizado, sem alterar o obs.
        nivel_adcp_comtide(idx_fim - n_blend + 1 : idx_fim) = (1 - w) .* borda_pred + w .* borda_obs;
    end
    
    fprintf('Blending no início em %.0f\n',ii)
end

%% Suavização pós-blending (para garantir suavização mais homogênea para as várias lacunas)

% Define largura da janela para aplicar média móvel após o blending, 
% promovendo suavização adicional e eliminando eventuais artefatos
% (ímpar de preferência, MÍNIMO = 3):
win_movmean = 3;
% Certifique-se que win_movmean é ímpar e >=3 como você comentou.
if mod(win_movmean,2) == 0 || win_movmean < 3
    error('win_movmean deve ser um número ímpar maior ou igual a 3 para esta suavização.');
end

% Cria cópia da série já com blending, para aplicar a suavização final 
% sem sobrescrever:
nivel_adcp_suave = nivel_adcp_comtide;  

% Aplica suavização em todas as lacunas detectadas:
for ii = 2:length(duracao_nan_index_global)
    
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    if idx_ini == length(nivel_adcp_suave)-1
        
        fprintf('Tentativa de suavizar o penúltimo ponto da série!\n')
        % Neste caso, a suavização não é feita e os pontos em questão são
        % substituídos pelo último valor observado:
        nivel_adcp_suave(idx_ini:end) = nivel_adcp_suave(idx_ini-1);
        
        continue
    end
    
    if idx_ini == length(nivel_adcp_suave)
        
        fprintf('Tentativa de suavizar o último ponto da série!\n')
        % Neste caso, a suavização não é feita e o ponto em questão é
        % substituído pelo último valor observado:
        nivel_adcp_suave(idx_ini) = nivel_adcp_suave(idx_ini-1);
        
        break
    end

    % Suavização borda inicial
    % Seleciona o trecho inicial após a lacuna e aplica filtro de 
    % média móvel:
    trecho_ini = nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1);
    media_ini = filter(ones(1, win_movmean)/win_movmean, 1, trecho_ini);
    % Ajusta a saída do filtro para compensar o atraso introduzido pelo 
    % filtro causal mantendo os primeiros win_movmean-1 pontos originais 
    % do trecho_ini (que são os pontos que o filtro causal ainda não "viu" 
    % o suficiente para calcular uma média completa) e usando os pontos 
    % filtrados e estáveis (media_ini(win_movmean:end)) para o restante do 
    % trecho (Isso é uma forma de criar uma transição suave para a média 
    % móvel, evitando um "salto" ou distorção abrupta no início do trecho 
    % filtrado.):
    nivel_adcp_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suavização borda final
    % Repete o mesmo processo na borda final, garantindo transição 
    % suave e sem descontinuidades:
    trecho_fim = nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim);
    media_fim = filter(ones(1, win_movmean)/win_movmean, 1, trecho_fim);
    nivel_adcp_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
    
    fprintf('Suavização no início em %.0f\n',ii)
end

%% Salva as variáveis

% Formato .mat:
fprintf('Salvando arquivo MAT...\n')

save (filename_output_mat,'nivel_adcp_suave');

% Formato .csv:

fprintf('Salvando arquivo CSV...\n')

dados_suavizados = dados(1:tamanho_tempo_total,1:6);
dados_suavizados(:,7) = nivel_adcp_suave;

% Assumindo que "dados_suavizados" é uma matriz numérica de 7 colunas
% [DD,MO,YYYY,HH,MM,SS,Nivel(m)]

% Crie uma tabela a partir da sua matriz para aproveitar o writetable
% E defina os nomes das colunas (cabeçalho)
T = array2table(dados_suavizados, 'VariableNames', {'DD','MO','YYYY','HH','MM','SS','Nivel_m'});

% Salva a tabela no formato CSV:
writetable(T, filename_output_csv, ...
    'Delimiter', ';', ... % Seu delimitador é ponto e vírgula
    'WriteVariableNames', true, ... % Escreve os nomes das variáveis (cabeçalho)
    'QuoteStrings', false, ... % Evita aspas em volta dos números, se não forem strings
    'FileType', 'text'); % Especifica que é um arquivo de texto


%% Plotagem para inspeção visual
%
% --- Plots: original, previsão harmônica, e previsão suavizada ---

% Inicializa figura, limpando qualquer plot anterior:
figure(1)
clf
hold on

% Plota todas as séries relevantes, cada uma com cor distinta e legenda, 
% permitindo comparação direta entre os diferentes estágios do 
% processamento

% Sinal original (com NaNs):
plot(nivel_adcp, 'k', 'DisplayName', 'Série original')

% Previsão harmônica antes do blending:
plot(nivel_adcp_comtide_raw, 'b', 'DisplayName', 'Previsão harmônica (raw)')

% Previsão harmônica suavizada (com blending):
plot(nivel_adcp_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending')

% Previsão harmônica pós-suavização com blending:
plot(nivel_adcp_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending e pós-suavização')

% Legenda e título:
legend('Location', 'best')
title('Preenchimento de lacunas com U-Tide e suavização por blending')
xlabel('Tempo (índice)')
ylabel('Nível do mar (m)')
grid on
box on


% Define uma lacuna específica para zoom e inspeção detalhada da 
% qualidade do preenchimento:

% Dica: para inspecionar outra lacuna, basta mudar o valor de 'indice_lacuna_plot' 
% e rodar novamente este bloco de código:
% =================================
indice_lacuna_plot = 9;
% Zoom automático na primeira lacuna para inspeção de spike
idx_zoom = ini_nan_index_global(indice_lacuna_plot);  % primeira lacuna
range_zoom = idx_zoom - 100 : idx_zoom + 100;
xlim([range_zoom(1) range_zoom(end)])
% =================================

% Sugestão de comando para salvar a figura com qualidade alta para 
% relatórios ou apresentações:
% print('nivel_mar_blending_zoom','-dpng','-r300')

fprintf('Feito!\n')

