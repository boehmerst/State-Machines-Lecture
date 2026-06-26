library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;

entity ampelsteuerung_tb is
end entity ampelsteuerung_tb;

architecture sim of ampelsteuerung_tb is

    --------------------------------------------------------------------
    -- Simulationsparameter
    --------------------------------------------------------------------
    constant C_CLK_FREQ_HZ : positive := 10;
    constant C_CLK_PERIOD  : time := 10 ns;

    -- Eine simulierte Sekunde entspricht G_CLK_FREQ_HZ Taktzyklen
    constant C_SIM_SECOND  : time := C_CLK_PERIOD * C_CLK_FREQ_HZ;

    --------------------------------------------------------------------
    -- DUT-Signale
    --------------------------------------------------------------------
    signal clk_i                : std_logic := '0';
    signal reset_i              : std_logic := '0';
    signal anforderungstaster_i : std_logic := '0';

    signal rot_o                : std_logic;
    signal gelb_o               : std_logic;
    signal gruen_o              : std_logic;

begin

    --------------------------------------------------------------------
    -- DUT-Instanz
    --------------------------------------------------------------------
    dut : entity work.ampelsteuerung
        generic map (
            G_CLK_FREQ_HZ => C_CLK_FREQ_HZ
        )
        port map (
            clk_i                => clk_i,
            reset_i              => reset_i,
            anforderungstaster_i => anforderungstaster_i,

            rot_o                => rot_o,
            gelb_o               => gelb_o,
            gruen_o              => gruen_o
        );

    --------------------------------------------------------------------
    -- Takterzeugung
    --------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk_i <= '0';
            wait for C_CLK_PERIOD / 2;
            clk_i <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;
    end process clk_process;

    --------------------------------------------------------------------
    -- Stimulus-Prozess
    --------------------------------------------------------------------
    stimulus_process : process
    begin

        ----------------------------------------------------------------
        -- Reset aktivieren
        ----------------------------------------------------------------
        report "Simulation gestartet";
        report "Reset wird aktiviert";

        reset_i <= '1';
        anforderungstaster_i <= '0';

        wait for 5 * C_CLK_PERIOD;

        ----------------------------------------------------------------
        -- Reset deaktivieren
        ----------------------------------------------------------------
        wait until rising_edge(clk_i);
        reset_i <= '0';

        report "Reset deaktiviert, Ampel sollte auf Gruen stehen";

        ----------------------------------------------------------------
        -- Nach Reset: 10 simulierte Sekunden Grünphase
        ----------------------------------------------------------------
        wait for 10 * C_SIM_SECOND;

        assert gruen_o = '1' and gelb_o = '0' and rot_o = '0'
            report "Fehler: Ampel ist nach 10 Sekunden nicht Gruen"
            severity error;

        report "Ampel war 10 simulierte Sekunden Gruen";

        ----------------------------------------------------------------
        -- Anforderungstaster betätigen
        ----------------------------------------------------------------
        report "Anforderungstaster wird gesetzt";

        anforderungstaster_i <= '1';
        wait for 3 * C_CLK_PERIOD;
        anforderungstaster_i <= '0';

        report "Anforderungstaster wurde wieder geloescht";

        ----------------------------------------------------------------
        -- Kurze Wartezeit wegen Eingangssynchronisation
        ----------------------------------------------------------------
        wait for 5 * C_CLK_PERIOD;

        ----------------------------------------------------------------
        -- Erwartet: Gelbphase für 3 Sekunden
        ----------------------------------------------------------------
        assert gruen_o = '0' and gelb_o = '1' and rot_o = '0'
            report "Fehler: Ampel ist nach Anforderung nicht auf Gelb"
            severity error;

        report "Ampel ist auf Gelb";

        wait for 3 * C_SIM_SECOND;

        ----------------------------------------------------------------
        -- Erwartet: Rotphase für 20 Sekunden
        ----------------------------------------------------------------
        wait for 2 * C_CLK_PERIOD;

        assert gruen_o = '0' and gelb_o = '0' and rot_o = '1'
            report "Fehler: Ampel ist nach Gelbphase nicht auf Rot"
            severity error;

        report "Ampel ist auf Rot";

        wait for 20 * C_SIM_SECOND;

        ----------------------------------------------------------------
        -- Erwartet: Gelb-Rot-Phase für 1 Sekunde
        ----------------------------------------------------------------
        wait for 2 * C_CLK_PERIOD;

        assert gruen_o = '0' and gelb_o = '1' and rot_o = '1'
            report "Fehler: Ampel ist nach Rotphase nicht auf Gelb-Rot"
            severity error;

        report "Ampel ist auf Gelb-Rot";

        wait for 1 * C_SIM_SECOND;

        ----------------------------------------------------------------
        -- Erwartet: Zurück auf Grün
        ----------------------------------------------------------------
        wait for 2 * C_CLK_PERIOD;

        assert gruen_o = '1' and gelb_o = '0' and rot_o = '0'
            report "Fehler: Ampel ist nach Gelb-Rot-Phase nicht wieder Gruen"
            severity error;

        report "Ampel ist wieder auf Gruen";
        report "Ampelzyklus erfolgreich abgeschlossen";

        ----------------------------------------------------------------
        -- Simulation beenden
        ----------------------------------------------------------------
        stop;

        wait;
    end process stimulus_process;

end architecture sim;
