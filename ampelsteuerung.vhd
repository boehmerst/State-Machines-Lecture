
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ampelsteuerung is
    generic (
        G_CLK_FREQ_HZ : positive := 50_000_000
    );
    port (
        clk_i                 : in  std_logic;
        reset_i               : in  std_logic;

        anforderungstaster_i  : in  std_logic;

        rot_o                 : out std_logic;
        gelb_o                : out std_logic;
        gruen_o               : out std_logic
    );
end entity ampelsteuerung;

architecture rtl of ampelsteuerung is

    --------------------------------------------------------------------
    -- Ampelzustände
    --------------------------------------------------------------------
    type t_ampel_state is (AMPEL_GRUEN, AMPEL_GELB, AMPEL_ROT, AMPEL_GELB_ROT);

    signal state      : t_ampel_state := AMPEL_GRUEN;
    signal next_state : t_ampel_state := AMPEL_GRUEN;

    --------------------------------------------------------------------
    -- Zeitkonstanten in Sekunden
    --------------------------------------------------------------------
    constant C_GELB_SECONDS      : natural := 3;
    constant C_ROT_SECONDS       : natural := 20;
    constant C_GELB_ROT_SECONDS  : natural := 1;
    constant C_MAX_SECONDS       : natural := C_ROT_SECONDS;

    subtype t_timer_seconds is natural range 0 to C_MAX_SECONDS;

    --------------------------------------------------------------------
    -- Timer-Signale
    --------------------------------------------------------------------
    signal timer_start        : std_logic := '0';
    signal timer_seconds_load : t_timer_seconds := 0;

    signal timer_running      : std_logic := '0';
    signal seconds_left       : t_timer_seconds := 0;

    signal clk_counter        : natural range 0 to G_CLK_FREQ_HZ - 1 := 0;

    signal timer_timeout      : std_logic;

    --------------------------------------------------------------------
    -- Synchronisation und Flankenerkennung des Tasters
    --------------------------------------------------------------------
    signal taster_sync_1 : std_logic := '0';
    signal taster_sync_2 : std_logic := '0';
    signal taster_sync_d : std_logic := '0';

    signal taster_rising_edge : std_logic;

begin

    --------------------------------------------------------------------
    -- Timeout-Signal
    --------------------------------------------------------------------
    timer_timeout <= '1' when
        timer_running = '1' and
        clk_counter = G_CLK_FREQ_HZ - 1 and
        seconds_left = 1
    else
        '0';

    --------------------------------------------------------------------
    -- Flankenerkennung des synchronisierten Tasters
    --------------------------------------------------------------------
    taster_rising_edge <= taster_sync_2 and not taster_sync_d;

    --------------------------------------------------------------------
    -- Eingangssynchronisation für anforderungstaster_i
    --
    -- Synchroner active-high Reset
    --------------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                taster_sync_1 <= '0';
                taster_sync_2 <= '0';
                taster_sync_d <= '0';
            else
                taster_sync_1 <= anforderungstaster_i;
                taster_sync_2 <= taster_sync_1;
                taster_sync_d <= taster_sync_2;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Zustandsregister
    --
    -- Synchroner active-high Reset
    --------------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                state <= AMPEL_GRUEN;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM: Folgezustandslogik und Timer-Steuerung
    --------------------------------------------------------------------
    process(state, taster_rising_edge, timer_timeout)
    begin
        next_state         <= state;
        timer_start        <= '0';
        timer_seconds_load <= 0;

        case state is

            ------------------------------------------------------------
            -- Defaultzustand: Grün
            ------------------------------------------------------------
            when AMPEL_GRUEN =>
                if taster_rising_edge = '1' then
                    next_state         <= AMPEL_GELB;
                    timer_start        <= '1';
                    timer_seconds_load <= C_GELB_SECONDS;
                end if;

            ------------------------------------------------------------
            -- Gelbphase: 3 Sekunden
            ------------------------------------------------------------
            when AMPEL_GELB =>
                if timer_timeout = '1' then
                    next_state         <= AMPEL_ROT;
                    timer_start        <= '1';
                    timer_seconds_load <= C_ROT_SECONDS;
                end if;

            ------------------------------------------------------------
            -- Rotphase: 20 Sekunden
            ------------------------------------------------------------
            when AMPEL_ROT =>
                if timer_timeout = '1' then
                    next_state         <= AMPEL_GELB_ROT;
                    timer_start        <= '1';
                    timer_seconds_load <= C_GELB_ROT_SECONDS;
                end if;

            ------------------------------------------------------------
            -- Gelb-Rot-Phase: 1 Sekunde
            ------------------------------------------------------------
            when AMPEL_GELB_ROT =>
                if timer_timeout = '1' then
                    next_state <= AMPEL_GRUEN;
                end if;

        end case;
    end process;

    --------------------------------------------------------------------
    -- Timer
    --
    -- Der Timer zählt ausgehend von G_CLK_FREQ_HZ echte Sekunden.
    -- Synchroner active-high Reset
    --------------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                timer_running <= '0';
                seconds_left  <= 0;
                clk_counter   <= 0;

            else
                if timer_start = '1' then
                    timer_running <= '1';
                    seconds_left  <= timer_seconds_load;
                    clk_counter   <= 0;

                elsif timer_running = '1' then

                    if clk_counter = G_CLK_FREQ_HZ - 1 then
                        clk_counter <= 0;

                        if seconds_left <= 1 then
                            seconds_left  <= 0;
                            timer_running <= '0';
                        else
                            seconds_left <= seconds_left - 1;
                        end if;

                    else
                        clk_counter <= clk_counter + 1;
                    end if;

                else
                    clk_counter <= 0;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Ausgangslogik
    --------------------------------------------------------------------
    rot_o <= '1' when
        state = AMPEL_ROT or
        state = AMPEL_GELB_ROT
    else
        '0';

    gelb_o <= '1' when
        state = AMPEL_GELB or
        state = AMPEL_GELB_ROT
    else
        '0';

    gruen_o <= '1' when
        state = AMPEL_GRUEN
    else
        '0';

end architecture rtl;

