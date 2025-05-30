%
% Script DE REVIS�O DE OFFSETS de pr�-processing dos dados de N�VEL DO MAR de ADCP da B�ia BH07.
% Hatsue Takanaca de Decco.
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio da intelig�ncia
% artificial ChatGPT (OpenAI), em maio de 2025.
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica da IA � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
% ------------------------------------------------------------
clear
clc

%% Abertura e Organiza��o dos dados

% Carrega o arquivo de dados originais (com falhas amostrais) da esta��o 
% BH07, contendo a s�rie temporal de n�vel do mar:

load D:\Hatsue\Dados_sismo\Estacao_Guanabara_BH_Boia_07\Dados_brutos_do_site\Estacao_Guanabara_BH_Boia_07_nivel.TXT

% Copia os dados para uma vari�vel com nome mais simples e limpa a 
% vari�vel original para economizar mem�ria:
dados = Estacao_Guanabara_BH_Boia_07_nivel;
clear Estacao_Guanabara_BH_Boia_07_nivel

% Carrega a s�rie de previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_n1_gapfilling_tide_codiga2011.m"):
load nivel_boia07_comtide.mat

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
nivel_boia07=dados(:,7);

% Guarda uma c�pia da previs�o harm�nica original para posterior 
% compara��o com a vers�o suavizada:
nivel_boia07_comtide_raw = nivel_boia07_comtide; 

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
        borda_obs = nivel_boia07_comtide(idx_ini - n_blend : idx_ini - 1);
        borda_pred = nivel_boia07_comtide(idx_ini : idx_ini + n_blend - 1);
        % Realiza interpola��o linear progressiva entre as bordas, 
        % suavizando a transi��o para evitar saltos abruptos:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_boia07_comtide(idx_ini - 1 + jj) = (1 - w) * borda_obs(jj) + w * borda_pred(jj);
        end
    end

    % Blending na borda final (ap�s a lacuna)
    % Garante que h� pontos suficientes ap�s a lacuna para aplicar o 
    % blending:
    if idx_fim + n_blend <= length(nivel_boia07_comtide)
        % Extrai bordas para suaviza��o: borda_pred (antes do fim da 
        % lacuna) e borda_obs (imediatamente ap�s a lacuna):
        borda_pred = nivel_boia07_comtide(idx_fim - n_blend + 1 : idx_fim);
        borda_obs = nivel_boia07_comtide(idx_fim + 1 : idx_fim + n_blend);
        % Aplica blending progressivo na borda final, com mesma l�gica de 
        % suaviza��o linear:
        for jj = 1:n_blend
            w = jj / (n_blend + 1);
            nivel_boia07_comtide(idx_fim - n_blend + jj) = (1 - w) * borda_pred(jj) + w * borda_obs(jj);
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
nivel_boia07_suave = nivel_boia07_comtide;  

% Aplica suaviza��o em todas as lacunas detectadas:
for ii = 2:length(duracao_nan_index_global)
    
    idx_ini = ini_nan_index_global(ii);
    idx_fim = fim_nan_index_global(ii);
    
    % Suaviza��o borda inicial
    % Seleciona o trecho inicial ap�s a lacuna e aplica filtro de 
    % m�dia m�vel:
    trecho_ini = nivel_boia07_suave(idx_ini : idx_ini + win_movmean - 1);
    media_ini = filter(ones(1, win_movmean)/win_movmean, 1, trecho_ini);
    % Ajusta a sa�da do filtro para compensar o atraso introduzido pelo 
    % filtro causal:
    nivel_boia07_suave(idx_ini : idx_ini + win_movmean - 1) = ...
        [trecho_ini(1:win_movmean-1); media_ini(win_movmean:end)];
    
    % Suaviza��o borda final
    % Repete o mesmo processo na borda final, garantindo transi��o 
    % suave e sem descontinuidades:
    trecho_fim = nivel_boia07_suave(idx_fim - win_movmean + 1 : idx_fim);
    media_fim = filter(ones(1, win_movmean)/win_movmean, 1, trecho_fim);
    nivel_boia07_suave(idx_fim - win_movmean + 1 : idx_fim) = ...
        [trecho_fim(1:win_movmean-1); media_fim(win_movmean:end)];
end

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
plot(nivel_boia07, 'k', 'DisplayName', 'S�rie original')

% Previs�o harm�nica antes do blending:
plot(nivel_boia07_comtide_raw, 'b', 'DisplayName', 'Previs�o harm�nica (raw)')

% Previs�o harm�nica suavizada (com blending):
plot(nivel_boia07_comtide, 'm', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending')

% Previs�o harm�nica p�s-suaviza��o com blending:
plot(nivel_boia07_suave, 'c', 'LineWidth', 1.2, 'DisplayName', 'Previs�o com blending e p�s-suaviza��o')

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


