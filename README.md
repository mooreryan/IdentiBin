# IdentiBin
(Known in another life as seanie_parallel)

This program has been designed for two primary purposes:

1. Identify **identical bins** from multiple assembly techniques so that the best version (i.e. most complete and least redundant/contaminated) of a bin can be selected.
2. Identify the amount of **new information** contained within one bin compared to another. Good for understanding how assembly techniques affect bin fidelity.

Admitedly, this is similar in purpose to other software packages, such as the excellent program [dRep](https://github.com/MrOlm/drep), though this could be used in conjunction. dRep uses ANI metrics to determine the relatedness of bins so that bins can be dereplicated. One potential pitfall in ANI is that the metric can be susceptible to incompleteness and contig fragmentation (the kind that you might see, for instance, when comparing assemblies of bins at different coverage levels). IdentiBin uses open reading frame (ORF) or amino acid calls to avoid these kinds of pitfalls.

The **main difference here is that we are comparing the percentage of novel 100% identical ORF clusters** between two bins. So, the resulting metric is EXTREMELY conservative. This was by design, so that we could identify bins from identical organisms between assemblies, not just closely related organisms within a species.

Another way to look at this metric (from the outfile):

```
info that b1 adds to b2 -- (1 - (num mixed clusters / total clusters with an ORF from b1)

b1 = bin of interest 1
b2 = bin of interest 2
num mixed clusters = number of shared 100% identical ORFs
total clusters with an ORF in b1 = total number of 100% identical ORFs in the bin of interest 1
```

## Dependencies

The following ruby gems must be installed: ```fileutils```, ```systemu```, ```parse_fasta```, ```abort_if```, ```parallel```.

To install:

```
gem install fileutils systemu parse_fasta abort_if parallel
```

## Installation

Download the repository from github: [IdentiBin](https://github.com/mooreryan/seanie_parallel)

## Usage

After installing, you can call the program with:

```
ruby ~/software/seanie_parallel/identibin.rb
```

This returns the usage information:

```
USAGE: ruby ~/software/seanie_parallel/identibin.rb num_threads tmpdir bin1_orfs.fa bin2_orfs.fa [bin3_orfs.fa ...] > jawns.txt
```

Arguments for the identibin.rb script are positional, meaning you must provide them in the order indicated.

```
num_threads = The max number of threads to use for parallelized pairwise comparisons
tmpdir = Directory for the storage of intermediate results and logs. Recommend you create a 'temp' directory for this.
bin1_orfs.fa = fasta formatted file with all ORFs or amino acid calls for a bin
bin2_orgs.fa = continue for each bin in the comparison
jawns.txt = generic output file name. Change it to what you like.
```

### Example:
The Zetaproteobacteria have several "species" defined by operational taxonomic unit (ZOTUs). Here we compare four bins from two ZOTUs and two assembly techniques.

|Bin|ZOTU|Assembly Technique|
|---|---|---|
|S1\_10\_Zeta1|ZOTU2|10% subassembly|
|S1\_Zeta1|ZOTU2|Individual sample assembly|
|S6\_Zeta10|ZOTU2|Individual sample assembly|
|S6\_Zeta3|ZOTU10|Individual sample assembly|

Running the script:

```
mkdir temp
ruby ~/software/seanie_parallel/identibin.rb 4 temp S1_10_Zeta1.faa S1_Zeta1_MANUALCURATION.faa S6_Zeta10_MANUALCURATION.faa S6_Zeta3_MANUALCURATION.faa > jawns.txt
```

Produces this outfile (```jawns.txt```):

|b1|b2|info that b1 adds to b2 -- (1 - (num mixed clusters / total clusters with an ORF from b1)|
|---|---|---|
|S1\_10\_Zeta1\_faa|S1\_Zeta1\_faa|<mark>**0.452431289640592**</mark>|
|S1\_Zeta1\_faa|S1\_10\_Zeta1\_faa|<mark>**0.468990261404408**</mark>|
|S6\_Zeta10\_faa|S1\_10\_Zeta1\_faa|0.9590371621621622|
|S1\_10\_Zeta1\_faa|S6\_Zeta10\_faa|0.9487315010570825|
|S6\_Zeta3\_faa|S1\_10\_Zeta1\_faa|1.0|
|S1\_10\_Zeta1\_faa|S6\_Zeta3\_faa|1.0|
|S6\_Zeta10\_faa|S1\_Zeta1\_faa|0.9569256756756757|
|S1\_Zeta1\_faa|S6\_Zeta10\_faa|0.9477191184008201|
|S1\_Zeta1\_faa|S6\_Zeta3\_faa|1.0|
|S6\_Zeta3\_faa|S1\_Zeta1\_faa|1.0|
|S6\_Zeta10\_faa|S6\_Zeta3\_faa|1.0|
|S6\_Zeta3\_faa|S6\_Zeta10\_faa|1.0|

From this outfile you can see that most of the bins share less than 5% of their 100% identical ORF clusters (i.e. have 95% or more novel information in the bin). The only two bin comparisons that share significant 100% ORF clusters are the two from the same organism from two different assemblies: S1\_10\_Zeta1 and S1\_Zeta1. Even comparisons from the same ZOTU (i.e. S1\_Zeta1 vs. S6\_Zeta10) share very few 100% identical ORFs.

Hopefully this illustrates how conservative and sensitive this technique is.

The GitHub for this program also includes a three column to matrix converter, ```three_col_to_matrix_converter.rb```, which can take the output from identibin.rb and convert it to a square matrix which can be imported into R and displayed graphically.

To run this program:

```
ruby ~/software/seanie_parallel/three_col_to_matrix_converter.rb jawns.txt > matrix.txt
```

The output file (```matrix.txt```) looks like:


||S1\_10\_Zeta1\_faa|S1\_Zeta1\_faa|S6\_Zeta10\_faa|S6\_Zeta3\_faa|
|---|---|---|---|---|
|S1\_10\_Zeta1\_faa|0|<mark>**0.452431289640592**</mark>|0.9487315010570825|1.0|
|S1\_Zeta1\_faa|<mark>**0.468990261404408**</mark>|0|0.9477191184008201|1.0|
|S6\_Zeta10\_faa|0.9590371621621622|0.9569256756756757|0|1.0|
|S6\_Zeta3\_faa|1.0|1.0|1.0|0|


Please open an issue if you have any issues or questions. This program is provided without warranty or a guarantee of support. Thanks!!
