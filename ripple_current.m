function i_ripple = ripple_current( bus_voltage, duty, fs, inductance)

i_ripple = bus_voltage / (fs * inductance) * (duty - duty * duty);

end

