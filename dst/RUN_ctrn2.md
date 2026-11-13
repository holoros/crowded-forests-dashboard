# RUN: rd_dst_ctrn2_20261112

- Date: 2026-11-12
- Host: firebreather
- R: R version 4.5.1 (2025-06-13)
- Packages: DBI 1.3.0, RSQLite 3.53.3, data.table 1.18.6.1
- Seed: 20261112 (bootstrap B = 2000, whole plot resampling; power simulation 20,000 draws)
- Wall time (R script): 101 s
- Scripts (md5):
  - 33900fdfb756cf69b6a82710d0242d1f  2026-11-12_rd-dst-ctrn2-validate.R
  - f22d6ee43cb5667f60ed756ec11bc0ba  run.sh
- Source databases (md5):
  - fb488bd2275470b969a7070be08e1f2b  ~/gydb2/build/ws/gydb-acadian/data/CFRU/CTRN/2_Standardized/Standardized.sqlite
  - ee3eacbe787ec840cae53a007467cc1a  ~/gydb2/build/ws/gydb-acadian/data/PEF/PCTF/2_Standardized/Standardized.sqlite (screened; 20 thinned plots with span, under the 30 plot rule, not analysed)
  - 5a2c500eee7878ff5b5002c92beb7c4e  ~/gydb2/build/ws/gydb-acadian/data/UNB/PSP16/2_Standardized/Standardized.sqlite
- Outputs: ctrn2_results_DATA.csv, ctrn2_class_means_DATA.csv, ctrn2_shuffle_DATA.csv, ctrn2_dataset_eligibility_DATA.csv, run.log
- Plot-level span tables stay on firebreather in _plotlevel/ (not exported).
- GitHub: pending
- Zenodo: not applicable
