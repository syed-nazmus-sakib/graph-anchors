#!/bin/bash
# E1 (supplement, 2026-11-19): is the short range of the latent goal cost universal across visual encoders?
# Same protocol and frames as exp-20 (exp20_range.sh): the 5-step grid of a seeded fifth of the episodes, 200 goals, rho(h)
# against a reference graph of true positions.  Encoders: LeWM (the world model of the paper), frozen DINOv2-S, raw pixels
# (control: no learned encoder), CLIP ViT-B/16, SigLIP-B/16, V-JEPA 2 ViT-L.  PLDM is not re-encoded (no checkpoint here);
# its exp-20 curve used the same frames and goals.  No planning runs.
# usage: bash scripts/run_range_diagnosis.sh <pmm|tworoom> <out dir>      (env: JEPAWM_HOME, SWM_PY, STABLEWM_HOME)
set -u
ENV=$1; D=$2; mkdir -p "$D"
REPO=${JEPAWM_HOME:?}; PY=${SWM_PY:?}; R=$REPO/scripts/run_eval.sh
P=$REPO/graph_anchors; SW=$REPO/third_party/stable-worldmodel
case $ENV in pmm) KEY=proprio; WM=yjang43/lp2-pointmaze-medium ;; tworoom) KEY=pos_agent; WM=quentinll/lewm-tworooms ;; *) echo "unknown env $ENV"; exit 1 ;; esac
FR=${EP_FRAC:-0.2}; NG=${N_GOALS:-200}; MAXN=${MAXN:-0}   # QUICK test: MAXN=512 N_GOALS=5
[ -f $D/lewm/dataset_name ] || OFFS=25 bash $R $ENV 0 $D/lewm setup
DS=$(cat $D/lewm/dataset_name)
cd $SW
L=""
for m in lewm dinov2 pixels clip siglip vjepa2; do
  arg=$m; [ $m = lewm ] && arg=$WM
  if [ ! -f $D/${m}_e.npz ]; then
    echo "[e1 $ENV] encode $m $(date +%T)"
    $PY $P/exp_encode.py --out $D/${m}_e.npz --model $arg --dataset $DS --state_key $KEY --ep_frac $FR --max_nodes $MAXN --batch ${BATCH:-128} \
      > $D/encode_$m.log 2>&1 || { echo "[e1 $ENV] encode $m FAILED (see $D/encode_$m.log)"; continue; }
  fi
  L="$L $m=$D/${m}_e.npz"
done
echo "[e1 $ENV] range on:$L $(date +%T)"
$PY $P/exp_range.py --out $D/range --n_goals $NG $L > $D/range.log 2>&1 || echo "[e1 $ENV] range FAILED"
[ -f $D/range.npz ] && cp $D/range.npz $D/range_npz.bin
echo "[e1 $ENV] done $(date +%T)"
