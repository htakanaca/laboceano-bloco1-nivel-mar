%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% utide_demo_chatgpt.m
%
% Descri��o:
% Script de demonstra��o e teste para verificar se o U-Tide (Codiga, 2011) 
% est� funcionando corretamente no ambiente MATLAB.
% 
% O script gera uma s�rie temporal sint�tica dominada pela componente 
% semidiurna M2, ajusta essa s�rie utilizando o U-Tide, reconstr�i o sinal 
% com os coeficientes harm�nicos e plota a s�rie original e reconstru�da.
%
% Autor: ChatGPT
% Data: Maio/2025
%
% Depend�ncias: 
% - U-Tide toolbox (https://www.mathworks.com/matlabcentral/fileexchange/46523-utide-unified-tidal-analysis-and-prediction-functions)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Gera��o da s�rie temporal sint�tica ---
t = datenum(2020, 1, 1, 0, 0, 0) + (0:0.5:15) / 24;  
% S�rie de 15 dias, com intervalo de 30 minutos

omega = 2 * pi / 12.42;  
% Frequ�ncia angular aproximada da componente M2 (ciclo de ~12.42 horas)

y = 1.5 * cos(omega * ((t - t(1)) * 24)) + 0.1 * randn(size(t));  
% Sinal sint�tico: componente M2 com amplitude de 1.5 m + ru�do gaussiano

lat = -23;  
% Latitude da esta��o (usada para corre��es astron�micas)

% --- Ajuste harm�nico utilizando U-Tide ---
coef = ut_solv(t, y, [], lat, 'auto');  
% Ajuste autom�tico sem sele��o pr�via de constituintes

% --- Reconstru��o da s�rie com os coeficientes ajustados ---
y_hat = ut_reconstr(t, coef);  
% Reconstru��o do sinal com base nos coeficientes harm�nicos

% --- Plotagem dos resultados ---
figure;
plot(t, y, 'k-', t, y_hat, 'r--');  
% S�rie original em preto e reconstru�da em tracejado vermelho

datetick('x', 'keeplimits');  
% Formata��o do eixo x em data

legend('Original', 'Reconstru�da');  
title('Teste U-Tide');  
xlabel('Tempo');  
ylabel('Altura (m)');  

% --- Fim do script ---
