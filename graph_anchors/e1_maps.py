"""E1 figures (supplement): for every encoder of the E1 run, (a) the top-3 principal components of its latents and (b) the
squared latent distance of every node to a few goals, plus the true-position reference distance (hops) to the same goals.
Small output for plotting on another machine: a fixed random subset of nodes (the same for all encoders).
usage: python e1_maps.py --dir <e1 out dir> --out maps.npz [--n_nodes 20000] [--n_goals 6]"""
import argparse, glob, os
import numpy as np
import torch
from scipy.sparse.csgraph import dijkstra
from exp_ref import ref_graph

ap = argparse.ArgumentParser()
ap.add_argument('--dir', required=True); ap.add_argument('--out', required=True)
ap.add_argument('--n_nodes', type=int, default=20000); ap.add_argument('--n_goals', type=int, default=6)
a = ap.parse_args()
files = {os.path.basename(f)[:-6]: f for f in sorted(glob.glob(os.path.join(a.dir, '*_e.npz')))}
ref = np.load(files['lewm'])
xy, ep, step = ref['state'][:, :2].astype(np.float32), ref['ep'], ref['step']
n = len(xy)
rng = np.random.default_rng(0)
sub = np.sort(rng.choice(n, min(a.n_nodes, n), replace=False))
G = ref_graph(xy, ep, step); GT = G.T.tocsr()
goals = []
while len(goals) < a.n_goals:                       # goals whose graph reaches far (long routes), spread over the map
    g = int(rng.integers(n)); d = dijkstra(GT, directed=True, indices=g)
    if np.isfinite(d).sum() > 0.8 * n and np.nanmax(np.where(np.isfinite(d), d, np.nan)) > 30:
        goals.append(g)
hops = np.stack([dijkstra(GT, directed=True, indices=g)[sub] for g in goals]).astype(np.float32)
out = dict(xy=xy[sub], ep=ep[sub], step=step[sub], goals=np.array(goals), goal_xy=xy[goals], hops=hops)
for k, f in files.items():
    e = torch.from_numpy(np.load(f)['emb'].astype(np.float32)).cuda()
    assert len(e) == n, (k, len(e), n)
    mu = e.mean(0, keepdim=True)
    U, S, V = torch.pca_lowrank(e - mu, q=3, center=False, niter=4)
    pcs = ((e - mu) @ V[:, :3])[torch.as_tensor(sub).cuda()]
    var = (S[:3] ** 2) / ((e - mu) ** 2).sum()
    cost = torch.stack([((e[torch.as_tensor(sub).cuda()] - e[g]) ** 2).sum(-1) for g in goals])
    out[f'pc_{k}'] = pcs.cpu().numpy().astype(np.float32); out[f'pcvar_{k}'] = var.cpu().numpy()
    out[f'cost_{k}'] = cost.cpu().numpy().astype(np.float32)
    print(k, 'explained variance of PC1-3:', np.round(var.cpu().numpy(), 3), flush=True)
    del e
np.savez_compressed(a.out, **out)
print('saved', a.out, {k: v.shape for k, v in out.items()}, flush=True)
