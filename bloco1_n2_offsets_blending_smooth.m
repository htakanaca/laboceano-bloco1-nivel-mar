%
% Script DE REVISÃO DE OFFSETS de pré-processing dos dados de NÌVEL DO MAR de ADCP da Bóia BH07.
% Hatsue Takanaca de Decco.
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio da inteligência
% artificial ChatGPT (OpenAI), em maio de 2025.
% A lógica foi construída a partir de instruções e ajustes
% fornecidos pela pesquisadora, garantindo coerência com os
% objetivos e critérios do estudo.
%
% A coautoria simbólica da IA é reconhecida no aspecto técnico,
% sem implicar autoria científica ou responsabilidade intelectual.
% ------------------------------------------------------------
clear
clc

%% Abertura e Organização dos dados

% Carrega o arquivo de dados originais (com falhas amostrais) da estação 
% BH07, contendo a série temporal de nível do mar:

load D:\Hatsue\Dados_sismo\Estacao_Guanabara_BH_Boia_07\Dados_brutos_do_site\Estacao_Guanabara_BH_Boia_07_nivel.TXT

% Copia os dados para uma variável com nome mais simples e limpa a 
% variável original para economizar memória:
dados = Estacao_Guanabara_BH_Boia_07_nivel;
clear Estacao_Guanabara_BH_Boia_07_nivel

% Carrega a série de previsão harmônica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_n1_gapfilling_tide_codiga2011.m"):
load nivel_boia07_comtide.mat

%% Definição de parâmetros e variáveis
%
% Identificação dos pontos de falhas amostrais originais para rastrear
% os pontos do vetor de nível do mar em que a previsão de maré inserida
% gerou offsets.
%

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
nivel_boia07=dados(:,7);

% Guarda uma cópia da previsão harmônica original para posterior 
% comparação com a versão suavizada:
nivel_boia07_comtide_raw = nivel_boia07_comtide; 

%% Blending nas bordas das lacunas
%
% Define quantos pontos serão usados em cada borda para realizar a 
% transição gradual entre observação e previsão, minimizando 
% descontinuidades:
n_blend = 3;


% Loop sobre todas as lacunas detectadas, começando da segunda posição, 
% para evitar problemas em bordas iniciais:
for ii=2:length(duracao_nan_index_global)
    
    
    % Define índices de início e fim da lacuna atual:
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Blending na borda inicial (antes da lacuna)
    % Garante que há dados suficientes antes da lacuna para aplicar o 
    % blending:
    if idx_ini - n_blend >= 1
        % Se houver dados suficientes antes da lacuna para aplicar o 
        % blending, separa borda_obs (dados imediatamente antes da lacuna) 
        % e borda_pred (dados previstos após a lacuna):
        borda_obs = nivel_boia07_comtide(idx_ini - n_blend : idx_ini - 1);
        borda_pred = nivel_boia07_comtide(idx_ini : idx_ini + n_blend - 1);
        % Realiza interpolação linear progressiva entre as bordas, 
        % suavizando a transição para evitar saltos abruptos:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_boia07_comtide(idx_ini - 1 + jj) = (1 - w) * borda_obs(jj) + w * borda_pred(jj);
        end
    end

    % Blending na borda final (após a lacuna)
    % Garante que há pontos suficientes após a lacuna para aplicar o 
    % blending:
    if idx_fim + n_blend <= length(nivel_boia07_comtide)
        % Extrai bordas para suavização: borda_pred (antes do fim da 
        % lacuna) e borda_obs (imediatamente após a lacuna):
        borda_pred = nivel_boia07_comtide(idx_fim - n_blend + 1 : idx_fim);
        borda_obs = nivel_boia07_comtide(idx_fim + 1 : idx_fim + n_blend);
        % Aplica blending progressivo na borda final, com mesma lógica de 
        % suavização linear:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_boia07_comtide(idx_fim - n_blend + jj) = (1 - w) * borda_pred(jj) + w * borda_obs(jj);
        end
    end
end

%% Segunda suavização pós-blending (para garantir suavização mais homogênea para as várias lacunas)

% Define largura da janela para aplicar média móvel após o blending, 
% promovendo suavização adicional e eliminando eventuais artefatos
% (ímpar de preferência):
win_movmean = 3;

% Cria cópia da série já com blending, para aplicar a suavização final 
% sem sobrescrever:
nivel_boia07_suave = nivel_boia07_comtide;  

% Aplica suavização em todas as lacunas detectadas:
for ii = 2:length(duracao_nan_index_global)
    
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suavização borda inicial
    % Seleciona o trecho inicial após a lacuna e aplica filtro de 
    % média móvel:
    trecho_ini = nivel_boia07_suave(idx_ini : idx_ini + win_movmean - 1);
    media_ini = filter(ones(1, win_movmean)/win_movmean, 1, trecho_ini);
    % Ajusta a saída do filtro para compensar o atraso introduzido pelo 
    % filtro causal:
    nivel_boia07_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suavização borda final
    % Repete o mesmo processo na borda final, garantindo transição 
    % suave e sem descontinuidades:
    trecho_fim = nivel_boia07_suave(idx_fim - win_movmean + 1 : idx_fim);
    media_fim = filter(ones(1, win_movmean)/win_movmean, 1, trecho_fim);
    nivel_boia07_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end

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
plot(nivel_boia07, 'k', 'DisplayName', 'Série original')

% Previsão harmônica antes do blending:
plot(nivel_boia07_comtide_raw, 'b', 'DisplayName', 'Previsão harmônica (raw)')

% Previsão harmônica suavizada (com blending):
plot(nivel_boia07_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending')

% Previsão harmônica pós-suavização com blending:
plot(nivel_boia07_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previsão com blending e pós-suavização')

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


