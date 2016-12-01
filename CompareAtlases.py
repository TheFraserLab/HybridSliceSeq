from __future__ import print_function
import PointClouds as pc
from matplotlib.pyplot import (scatter, gca, figure, pcolormesh, title)
from matplotlib import cm
from numpy import zeros, zeros_like, nanmedian, nanpercentile
import numpy as np
import pandas as pd
from sys import stderr
from multiprocessing import Pool
from progressbar import ProgressBar

def find_best_match(s1_pos, s1_expr, s2_pos, s2_expr):
    """Find the best-matching nucleus within a given time point

    Note that unlike in Fowlkes 2011, I am using only the provided time point
    (and assuming that the input atlases have already been sliced), since the
    positions change, and so I don't know what to make of the "30 nearest nuclei
    to be matched" statement.

    """
    best_N = 30
    dists = (
        (s1_pos.pctX - s2_pos.pctX)**2
        + (s1_pos.pctY - s2_pos.pctY)**2
        + (s1_pos.pctZ - s2_pos.pctZ)**2
    )

    dists.sort_values(inplace=True)
    dists = dists[:best_N]

    expr_dists = ((s1_expr - s2_expr.ix[dists.index, :])**2).sum(axis=1)


    return expr_dists.idxmin()

def find_all_matches(s1_pos, s1_expr, s2_pos, s2_expr, pool=False, drop_genes=False):
    if 'X' in s1_pos.index:
        s1_pos = s1_pos.T
    if 'X' in s2_pos.index:
        s2_pos = s2_pos.T

    if 'bcd' in s1_expr.index:
        s1_expr = s1_expr.T
    if 'bcd' in s2_expr.index:
        s2_expr = s2_expr.T

    in_both = s1_expr.columns.intersection(s2_expr.columns)
    if drop_genes:
        in_both = in_both.drop(drop_genes)
    s1_expr = s1_expr.ix[:, in_both]
    s2_expr = s2_expr.ix[:, in_both]

    out = pd.Series(index=s1_expr.index, data=0)
    pbar = ProgressBar(maxval=len(out))
    if pool is None:
       pool = Pool()
    if pool is False:
        for nuc in pbar(out.index):
            out.ix[nuc] = (
                find_best_match(s1_pos.ix[nuc, :], s1_expr.ix[nuc,:], s2_pos, s2_expr)
            )
        return out

    results = []
    for nuc in out.index:
        results.append(
            pool.apply_async(
                find_best_match,
                (s1_pos.ix[nuc, :], s1_expr.ix[nuc, :], s2_pos, s2_expr)
            )
        )
    for res, ix in pbar(zip(results, out.index)):
        out.ix[ix] = res.get()

    return out


bg_regions = {
    'hb': (55, 70),
    'Kr': (62, 85),
    'hkb': (15, 85),
}

if __name__ == "__main__":
    target = 'hb'
    both_stage = '5:26-50'
    mel_stage = both_stage
    sim_stage = both_stage
    if 'sim_atlas' not in locals():
        sim_atlas = pc.PointCloudReader(open('prereqs/dsim-20120727-r2-ZW.vpc'))
        mel_atlas = pc.PointCloudReader(open('prereqs/D_mel_wt__atlas_r2.vpc'))
    else:
        print("Using preloaded data", file=stderr)
    sim_atlas_expr, sim_atlas_pos = sim_atlas.data_to_arrays(usecohorts=True)
    mel_atlas_expr, mel_atlas_pos = mel_atlas.data_to_arrays(usecohorts=True)

    sim_atlas_pos.ix[:, 'pctX', :] = 100*(sim_atlas_pos[:, 'X', :].subtract(sim_atlas_pos[:, 'X', :].min(axis=1), axis=0)).divide(sim_atlas_pos[:, 'X', :].max(axis=1) - sim_atlas_pos[:, 'X', :].min(axis=1), axis=0)
    sim_atlas_pos.ix[:, 'pctY', :] = 100*(sim_atlas_pos[:, 'Y', :].subtract(sim_atlas_pos[:, 'Y', :].min(axis=1), axis=0)).divide(sim_atlas_pos[:, 'Y', :].max(axis=1) - sim_atlas_pos[:, 'Y', :].min(axis=1), axis=0)
    sim_atlas_pos.ix[:, 'pctZ', :] = 100*(sim_atlas_pos[:, 'Z', :].subtract(sim_atlas_pos[:, 'Z', :].min(axis=1), axis=0)).divide(sim_atlas_pos[:, 'Z', :].max(axis=1) - sim_atlas_pos[:, 'Z', :].min(axis=1), axis=0)
    mel_atlas_pos.ix[:, 'pctX', :] = 100*(mel_atlas_pos[:, 'X', :].subtract(mel_atlas_pos[:, 'X', :].min(axis=1), axis=0)).divide(mel_atlas_pos[:, 'X', :].max(axis=1) - mel_atlas_pos[:, 'X', :].min(axis=1), axis=0)
    mel_atlas_pos.ix[:, 'pctY', :] = 100*(mel_atlas_pos[:, 'Y', :].subtract(mel_atlas_pos[:, 'Y', :].min(axis=1), axis=0)).divide(mel_atlas_pos[:, 'Y', :].max(axis=1) - mel_atlas_pos[:, 'Y', :].min(axis=1), axis=0)
    mel_atlas_pos.ix[:, 'pctZ', :] = 100*(mel_atlas_pos[:, 'Z', :].subtract(mel_atlas_pos[:, 'Z', :].min(axis=1), axis=0)).divide(mel_atlas_pos[:, 'Z', :].max(axis=1) - mel_atlas_pos[:, 'Z', :].min(axis=1), axis=0)


    mel_front_10 = mel_atlas_pos.ix[:, 'pctX', mel_stage] <= 10
    sim_front_10 = sim_atlas_pos.ix[:, 'pctX', sim_stage] <= 10

    mel_selector = (mel_atlas_expr[:, target, mel_stage] > .3) & (mel_atlas_pos.ix[:, 'pctX', mel_stage] > 75)
    sim_selector = (sim_atlas_expr[:, target, sim_stage] > .3) & (sim_atlas_pos.ix[:, 'pctX', sim_stage] > 75)

    bg_lo, bg_hi = bg_regions[target]
    mel_background = ((bg_lo < mel_atlas_pos.ix[:, 'pctX', mel_stage])
                      & (mel_atlas_pos.ix[:, 'pctX', mel_stage] < bg_hi))
    mel_post_strip = ((75 < mel_atlas_pos.ix[:, 'pctX', mel_stage])
                      & (mel_atlas_expr.ix[:, target, mel_stage] > .3))
    sim_background = ((bg_lo < sim_atlas_pos.ix[:, 'pctX', sim_stage])
                      & (sim_atlas_pos.ix[:, 'pctX', sim_stage] < bg_hi))
    sim_post_strip = ((75 < sim_atlas_pos.ix[:, 'pctX', sim_stage])
                      & (sim_atlas_expr.ix[:, target, sim_stage] > .3))

    print(
        '\nmel in region',
        mel_atlas_expr.ix[mel_selector, target, mel_stage].mean(),
        '\nsim in region',
        sim_atlas_expr.ix[sim_selector, target, sim_stage].mean(),
        '\nmel front 10',
        mel_atlas_expr.ix[mel_front_10, target, mel_stage].mean(),
        '\nsim front 10',
        sim_atlas_expr.ix[sim_front_10, target, sim_stage].mean(),
    )

    #scatter(mel_atlas_pos[:, 'X', mel_stage], mel_atlas_pos[:, 'Z', mel_stage], c=mel_selector, s=80)
    #scatter(sim_atlas_pos[:, 'X', sim_stage], sim_atlas_pos[:, 'Z', sim_stage], c=sim_selector, s=80)

    mel_expr_at_stage = (
        mel_atlas_expr.ix[:, target, mel_stage]
        - np.nanmean(mel_atlas_expr.ix[mel_background, target, mel_stage])
    ).clip(0, np.inf)
    mel_expr_at_stage /= np.nanpercentile(
        mel_atlas_expr.ix[~mel_background, target, mel_stage],
        90
    )
    sim_expr_at_stage = (
        sim_atlas_expr.ix[:, target, sim_stage]
        - np.nanmean(sim_atlas_expr.ix[sim_background, target, sim_stage])
    ).clip(0, np.inf)
    sim_expr_at_stage /= np.nanpercentile(
        sim_atlas_expr.ix[~sim_background, target, sim_stage],
        90
    )

    if locals().get('calc_grid', False):
        factor = 3
        # 100% plus a hair to be safe.
        mel_grid_expr = zeros((101//factor+1, 101//factor+1))
        mel_grid_ns = zeros_like(mel_grid_expr)
        sim_grid_expr = zeros((101//factor+1, 101//factor+1))
        sim_grid_ns = zeros_like(sim_grid_expr)

        for x, z, expr in zip(mel_atlas_pos.ix[:, 'pctX', mel_stage],
                              mel_atlas_pos.ix[:, 'pctZ', mel_stage],
                              mel_expr_at_stage):
            x = int(x)//factor
            z = int(z)//factor
            mel_grid_expr[z, x] += expr
            mel_grid_ns[z, x] += 1

        for x, z, expr in zip(sim_atlas_pos.ix[:, 'pctX', sim_stage],
                              sim_atlas_pos.ix[:, 'pctZ', sim_stage],
                              sim_expr_at_stage):
            x = int(x)//factor
            z = int(z)//factor
            sim_grid_expr[z, x] += expr
            sim_grid_ns[z, x] += 1

        mel_grid_avg = mel_grid_expr / mel_grid_ns
        sim_grid_avg = sim_grid_expr / sim_grid_ns


        mel_grid_lo = nanpercentile(mel_grid_avg, 10)
        mel_grid_hi = nanpercentile(mel_grid_avg, 90)
        sim_grid_lo = nanpercentile(sim_grid_avg, 10)
        sim_grid_hi = nanpercentile(sim_grid_avg, 90)
        mel_grid_avg = (mel_grid_avg - mel_grid_lo) / (mel_grid_hi - mel_grid_lo)
        sim_grid_avg = (sim_grid_avg - sim_grid_lo) / (sim_grid_hi - sim_grid_lo)

        ax = gca()
        ax.set_aspect(1)

        denom_i = (sim_grid_avg + mel_grid_avg)


        figure()
        heatmap = pcolormesh((sim_grid_avg - mel_grid_avg) / np.where(denom_i > .5,
                                                                      denom_i,  np.nan),
                   vmin=-1, vmax=1, cmap=cm.RdBu)
        heatmap.cmap.set_bad((.5, .5, .5))
        heatmap.cmap.set_under((.5, .5, .5))

    best_matches = find_all_matches(mel_atlas_pos.ix[:, :, mel_stage],
                                    mel_atlas_expr.ix[:, :, mel_stage],
                                    sim_atlas_pos.ix[:, :, sim_stage],
                                    sim_atlas_expr.ix[:, :, sim_stage],
                                    drop_genes=[ target, 'bcd'])

    sim_expr_at_matching = pd.Series(index=mel_expr_at_stage.index,
                                     data=list(sim_expr_at_stage[best_matches]))


    figure()
    denom =  (mel_expr_at_stage.clip(0, 20) + sim_expr_at_matching.clip(0, 20))
    co = .05
    scatter(
        mel_atlas_pos.ix[:, 'pctX', mel_stage],
        mel_atlas_pos.ix[:, 'pctZ', mel_stage],
        c=(mel_expr_at_stage - sim_expr_at_matching)
        /denom.where(denom > co) ,
        cmap=cm.RdBu_r, vmin=-1, vmax=1, s=80,
        edgecolor=(0, 0, 0, 0)
    )
    title(mel_stage + '/' + sim_stage)

