clear;
clc;
close all;

%% =========================================================
%  ACQUISIZIONE SEGNALE SYNTH DA ARDUINO UNO
%  Porta: COM3
%  Arduino acquisisce 500 campioni e poi li trasmette
% ==========================================================

porta = "COM3";
baud = 115200;
N = 500;

%% 1. Collegamento seriale

disp("Connessione ad Arduino...");

s = serialport(porta, baud);
configureTerminator(s, "LF");

% Timeout più lungo per evitare errori di lettura
s.Timeout = 10;

% L'apertura della porta può resettare Arduino
pause(2);

% Elimina eventuali dati residui
flush(s);

disp("Arduino connesso.");

%% 2. Avvio acquisizione

disp("Avvio acquisizione...");

% Invia il carattere S ad Arduino
write(s, 'S', "char");

%% 3. Ricezione durata acquisizione

riga = strtrim(readline(s));

disp("Risposta Arduino: " + riga);

parti = split(riga, ",");

if numel(parti) ~= 2 || parti(1) ~= "DURATION"
    clear s;
    error("Risposta Arduino non valida: " + riga);
end

duration_us = str2double(parti(2));

%% 4. Ricezione dei 500 campioni

adc = zeros(N,1);

for i = 1:N

    riga = strtrim(readline(s));

    valore = str2double(riga);

    if isnan(valore)
        clear s;
        error("Campione non valido ricevuto alla posizione %d.", i);
    end

    adc(i) = valore;

end

%% 5. Controllo marker END

fine = strtrim(readline(s));

if fine ~= "END"
    warning("Marker END non ricevuto correttamente.");
end

disp("Acquisizione completata.");

%% 6. Calcolo frequenza di campionamento

Ttot = duration_us * 1e-6;

Ts = Ttot / N;

fs = 1 / Ts;

fprintf("\n------------------------------\n");
fprintf("RISULTATI ACQUISIZIONE\n");
fprintf("------------------------------\n");

fprintf("Numero campioni: %d\n", N);
fprintf("Durata acquisizione: %.6f s\n", Ttot);
fprintf("Ts medio: %.2f us\n", Ts*1e6);
fprintf("fs media: %.2f Hz\n", fs);
fprintf("Frequenza di Nyquist: %.2f Hz\n", fs/2);

%% 7. Creazione asse temporale

t = (0:N-1)' * Ts;

%% 8. Grafico del segnale ADC

figure;

plot(t, adc);

xlabel("Tempo [s]");
ylabel("Valore ADC [0-1023]");
title("Segnale acquisito dal sintetizzatore");

grid on;

%% 9. Salvataggio dati

T = table(t, adc);

writetable(T, "synth_measurement.csv");

disp("Dati salvati in synth_measurement.csv");

%% 10. Libera la porta seriale

clear s;

disp("COM3 liberata.");

%% Conversione ADC -> tensione

Vref = 5.0;

vA0 = (adc / 1023) * Vref;

% Ricostruzione approssimata della tensione prima
% del partitore 10k-10k
vSynth = 2 * vA0;

figure;
plot(t, vSynth);

xlabel("Tempo [s]");
ylabel("Tensione [V]");
title("Segnale NE555 - dominio del tempo");

grid on;

x = vSynth - mean(vSynth);

%% FFT

Nfft = length(x);

X = fft(x);

P2 = abs(X / Nfft);

P1 = P2(1:floor(Nfft/2)+1);

P1(2:end-1) = 2 * P1(2:end-1);

f = fs * (0:floor(Nfft/2)) / Nfft;

figure;
plot(f, P1);

xlabel("Frequenza [Hz]");
ylabel("Ampiezza");
title("Spettro del segnale - FFT");

grid on;
xlim([0 fs/2]);

%% Stima frequenza fondamentale

[~, indice] = max(P1(2:end));

indice = indice + 1;

f0 = f(indice);

fprintf("\nFrequenza fondamentale stimata: %.2f Hz\n", f0);