%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% utide_demo_chatgpt.m
%
% Descrição:
% Script de demonstração e teste para verificar se o U-Tide (Codiga, 2011) 
% está funcionando corretamente no ambiente MATLAB.
% 
% O script gera uma série temporal sintética dominada pela componente 
% semidiurna M2, ajusta essa série utilizando o U-Tide, reconstrói o sinal 
% com os coeficientes harmônicos e plota a série original e reconstruída.
%
% Autor: ChatGPT
% Data: Maio/2025
%
% Dependências: 
% - U-Tide toolbox (https://www.mathworks.com/matlabcentral/fileexchange/46523-utide-unified-tidal-analysis-and-prediction-functions)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Geração da série temporal sintética ---
t = datenum(2020, 1, 1, 0, 0, 0) + (0:0.5:15) / 24;  
% Série de 15 dias, com intervalo de 30 minutos

omega = 2 * pi / 12.42;  
% Frequência angular aproximada da componente M2 (ciclo de ~12.42 horas)

y = 1.5 * cos(omega * ((t - t(1)) * 24)) + 0.1 * randn(size(t));  
% Sinal sintético: componente M2 com amplitude de 1.5 m + ruído gaussiano

lat = -23;  
% Latitude da estação (usada para correções astronômicas)

% --- Ajuste harmônico utilizando U-Tide ---
coef = ut_solv(t, y, [], lat, 'auto');  
% Ajuste automático sem seleção prévia de constituintes

% --- Reconstrução da série com os coeficientes ajustados ---
y_hat = ut_reconstr(t, coef);  
% Reconstrução do sinal com base nos coeficientes harmônicos

% --- Plotagem dos resultados ---
figure;
plot(t, y, 'k-', t, y_hat, 'r--');  
% Série original em preto e reconstruída em tracejado vermelho

datetick('x', 'keeplimits');  
% Formatação do eixo x em data

legend('Original', 'Reconstruída');  
title('Teste U-Tide');  
xlabel('Tempo');  
ylabel('Altura (m)');  

% --- Fim do script ---
