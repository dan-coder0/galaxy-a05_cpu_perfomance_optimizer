#!/system/bin/sh

CONFIG_FILE="${1:-$HOME/perforx.conf}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' 

LOG_DIR="/storage/emulated/0/Documents"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/perforx.log"


log() {
  
  echo "$LOGFILE"
}

SWITCH_THRESHOLD_CPU_PERCENT=40
POWERSAVE_GOVERNOR="powersave"
PERFORMANCE_GOVERNOR="performance"
POWERSAVE_MAX_FREQ_MHZ=1000
PERFORMANCE_MAX_FREQ_MHZ=1800

CPU_DIR="/sys/devices/system/cpu"

if [ -f "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
  echo -e "${GREEN}Loaded config from ${CONFIG_FILE}${NC}"
  log "Loaded config from ${CONFIG_FILE}"
else
  echo -e "${YELLOW}Config file not found at ${CONFIG_FILE}, using default settings.${NC}"
  log "Config file not found at ${CONFIG_FILE}, using default settings"
fi

# Add checks before reading CPU frequency files
if [ -r "$CPU_DIR/cpu0/cpufreq/scaling_min_freq" ]; then
  POWERSAVE_MIN_FREQ_MHZ=$(($(cat "$CPU_DIR/cpu0/cpufreq/scaling_min_freq") / 1000))
  PERFORMANCE_MIN_FREQ_MHZ=$(($(cat "$CPU_DIR/cpu0/cpufreq/scaling_min_freq") / 1200))
else
  POWERSAVE_MIN_FREQ_MHZ=1000
  PERFORMANCE_MIN_FREQ_MHZ=1000
  echo -e "${RED}Cannot read scaling_min_freq, using default value.${NC}"
  log "Cannot read scaling_min_freq, using default value."
fi

set_governor() {
  governor="$1"
  echo -e "${MAGENTA}Setting governor to: ${CYAN}$governor${NC}"
  log "Setting governor to: $governor"
  for freq_dir in "$CPU_DIR"/cpu*/cpufreq; do
    echo "$governor" > "$freq_dir"/scaling_governor
  done
}

set_min_freq() {
  min_freq_mhz="$1"
  min_freq_khz=$((min_freq_mhz * 1000))
  echo -e "${MAGENTA}Setting minimum frequency to: ${CYAN}$min_freq_mhz MHz (${min_freq_khz} kHz)${NC}"
  log "Setting minimum frequency to: ${min_freq_mhz} MHz (${min_freq_khz} kHz)"
  for freq_dir in "$CPU_DIR"/cpu*/cpufreq; do
    echo "$min_freq_khz" > "$freq_dir"/scaling_min_freq
  done
}

set_max_freq() {
  max_freq_mhz="$1"
  max_freq_khz=$((max_freq_mhz * 1000))
  echo -e "${MAGENTA}Setting maximum frequency to: ${CYAN}$max_freq_mhz MHz (${max_freq_khz} kHz)${NC}"
  log "Setting maximum frequency to: ${max_freq_mhz} MHz (${max_freq_khz} kHz)"
  for freq_dir in "$CPU_DIR"/cpu*/cpufreq; do
    echo "$max_freq_khz" > "$freq_dir"/scaling_max_freq
  done
}

get_cpu_usage() {
  total=$(cat /proc/stat | grep '^cpu ' | awk '{sum=0; for(i=2; i<=NF; i++) sum+=$i; print sum}')
  idle=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
  usage=0
  if [ "$prev_total" ] && [ "$prev_idle" ]; then
    diff_total=$((total - prev_total))
    diff_idle=$((idle - prev_idle))
    diff_usage=$((diff_total - diff_idle))
    if [ $diff_total -ne 0 ]; then
      usage=$((100 * diff_usage / diff_total))
    fi
  fi
  prev_total=$total
  prev_idle=$idle
  echo $usage
}

prev_total=0
prev_idle=0
CURRENT_MODE=""

echo -e "\n${GREEN}Starting Perfor-X™ - Dynamic CPU Performance Optimization...${NC}"
log "Script started"
echo -e "${YELLOW}Press Ctrl+C to stop.${NC}"

while true; do
  cpu_usage=$(get_cpu_usage)
  echo -e "${CYAN}Current CPU usage: ${cpu_usage}%${NC}"
  log "Current CPU usage: ${cpu_usage}%"

  if [ "$cpu_usage" -lt "$SWITCH_THRESHOLD_CPU_PERCENT" ]; then
    if [ "$CURRENT_MODE" != "powersave" ]; then
      set_governor "$POWERSAVE_GOVERNOR"
      set_min_freq "$POWERSAVE_MIN_FREQ_MHZ"
      set_max_freq "$POWERSAVE_MAX_FREQ_MHZ"
      CURRENT_MODE="powersave"
      echo -e "${BLUE}Mode: ${GREEN}Powersave (${CYAN}$POWERSAVE_GOVERNOR${CYAN})${NC}"
      log "Switched to powersave mode"
    fi
  else
    if [ "$CURRENT_MODE" != "performance" ]; then
      set_governor "$PERFORMANCE_GOVERNOR"
      set_min_freq "$PERFORMANCE_MIN_FREQ_MHZ"
      set_max_freq "$PERFORMANCE_MAX_FREQ_MHZ"
      CURRENT_MODE="performance"
      echo -e "${BLUE}Mode: ${RED}Performance (${CYAN}$PERFORMANCE_GOVERNOR${CYAN})${NC}"
      log "Switched to performance mode"
    fi
  fi

  sleep 2
done
