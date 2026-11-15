#!/bin/bash
# exp-38 (2026-11-14): can graph anchors fix the focus failure on manipulation?  (lab-9; evaluation only, no training)
# Hypothesis: with a cost that weighs the robot over the object, a target helps only if it is near AND stays on recorded contact.
#   So nearer anchors (K = 2-3 hops, plan executed to its closest approach) and routes kept on recorded transitions (episode-switch
#   cost 3) should close most of the gap to AP (which aims one recorded frame ahead: Push-T 66, Cube 56 at d=150).
# Pre-stated decision (seed 0, d=150, 50 pairs):
#   GO    if the best new configuration reaches >= 45 on Push-T and >= 40 on Cube AND beats the same-machine K=6 reference by >= 15
#         points on both -> confirm that configuration on seeds 42 and 1 (FOCUS_CONFIRM=1).
#   NO-GO otherwise: the focus failure stays open and is reported as such.
# Configurations: ga_sp6 (default, reference), apcem (AP, reference) | ga_mp3 K=3 pass-through | ga_mp3sw3 + switch cost 3 | ga_mp2sw3 K=2 + switch 3 |
#                 gam_sp1, gam_sp2: our anchor 1 or 2 hops ahead under AP's planner (one-block CEM, replan every block).
# Every configuration waits until the shared GPU has NEED_GB free and the host has NEED_RAM_GB available (other users' jobs run there).
ROOT=${ROOT:-/media/rmedu-04/Storage2/world-model-goal-costs}
export JEPAWM_HOME=$ROOT SWM_PY=$HOME/anaconda3/envs/gwm/bin/python PATH=$HOME/anaconda3/envs/gwm/bin:$PATH
export PYTHONPATH=$ROOT/code/third_party/stable-worldmodel STABLEWM_HOME=$HOME/sakib_gwm/stable_worldmodel
export MUJOCO_GL=egl PYOPENGL_PLATFORM=egl SDL_VIDEODRIVER=dummy CUDA_VISIBLE_DEVICES=0
source $ROOT/scripts/hpc/egl.sh
source $ROOT/scripts/exp/gpu_wait.sh 2>/dev/null || source $HOME/sakib_gwm/gpu_wait.sh
wait_ram() { local a; while a=$(free -g | awk '/^Mem:/ {print $7}'); [ "$a" -lt "${NEED_RAM_GB:-8}" ]; do
  echo "$(date '+%F %T') host has $a GB available, waiting for ${NEED_RAM_GB:-8} GB"; sleep 300; done; }
gate() { wait_vram ${NEED_GB:-5}; wait_ram; }
R=$ROOT/scripts/pod/run_ga_env.sh
SEEDS=${FOCUS_SEEDS:-0}; OFF=${FOCUS_OFF:-150}
for e in ${FOCUS_ENVS:-pusht cube}; do
  case $e in pusht) O=$ROOT/out/exp36/pusht ;; *) O=$ROOT/out/exp38/$e ;; esac   # Push-T nodes shared with exp-37
  gate; OFFS=25 bash $R $e 0 $O setup || { echo "setup $e FAILED"; continue; }
  if [ -z "${FOCUS_CONFIRM:-}" ]; then
    gate; OFFS="$OFF" SPANS=6 bash $R $e "$SEEDS" $O anchor      # reference: default graph anchors
    gate; OFFS="$OFF" bash $R $e "$SEEDS" $O ap                    # reference: AP on the same machine and pairs
  fi
  for cfg in ${FOCUS_CFGS:-mp3 mp3sw3 mp2sw3 match}; do
    gate
    case $cfg in
      mp3)    TAG=_mp3    HA=3 EVX="plan_config.receding_horizon=3 +paa_exec=pass" OFFS="$OFF" SPANS=3 bash $R $e "$SEEDS" $O anchor ;;
      mp3sw3) TAG=_mp3sw3 HA=3 EVX="plan_config.receding_horizon=3 +paa_exec=pass +paa_switch=3" OFFS="$OFF" SPANS=3 bash $R $e "$SEEDS" $O anchor ;;
      mp2sw3) TAG=_mp2sw3 HA=2 EVX="plan_config.receding_horizon=2 +paa_exec=pass +paa_switch=3" OFFS="$OFF" SPANS=2 bash $R $e "$SEEDS" $O anchor ;;
      match)  MSPANS="1 2" OFFS="$OFF" bash $R $e "$SEEDS" $O match ;;
    esac
  done
done
echo EXP38_DONE
