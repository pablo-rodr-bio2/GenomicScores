## This file explains the steps to download and freeze the phastCons
## conservation scores for human genome version hg19, calculated on
## 33 placental mammals. If you use these data on your own research
## please cite the following publication:

## Siepel A, Bejerano G, Pedersen JS, Hinrichs AS, Hou M, Rosenbloom K, Clawson H,
## Spieth J, Hillier LW, Richards S, et al. Evolutionarily conserved elements
## in vertebrate, insect, worm, and yeast genomes. Genome Res. 2005 Aug;15(8):1034-50.
## (http://www.genome.org/cgi/doi/10.1101/gr.3715005)

## The data were downloaded from the UCSC genome browser with the Unix 'rsync'
## command as follows
##
## $ rsync -avz --progress \
##     rsync://hgdownload.soe.ucsc.edu/goldenPath/hg38/phastCons30way/hg38.30way.phastCons/ \
##     ./phastCons30way

## The following R script processes the downloaded data to
## store the phastCons scores in raw-Rle objects

library(BSgenome.Hsapiens.UCSC.hg38)
library(rtracklayer)
library(doParallel)
library(S4Vectors)

downloadURL <- "http://hgdownload.soe.ucsc.edu/goldenPath/hg38/phastCons30way/hg38.30way.phastCons"
citationdata <- bibentry(bibtype="Article",
                         author=c(person("Adam Siepel"), person("Gill Berejano"), person("Jakob S. Pedersen"),
                                  person("Angie S. Hinrichs"), person("Minmei Hou"), person("Kate Rosenbloom"),
                                  person("Hiram Clawson"), person("John Spieth"), person("LaDeana W. Hillier"),
                                  person("Stephen Richards"), person("George M. Weinstock"),
                                  person("Richard K. Wilson"), person("Richard A. Gibbs"),
                                  person("W. James Kent"), person("Webb Miller"), person("David Haussler")),
                         title="Evolutionarily conserved elements in vertebrate, insect, worm, and yeast genomes",
                         journal="Genome Research",
                         volume="15",
                         pages="1034-1050",
                         year="2005",
                         doi="10.1101/gr.3715005")

registerDoParallel(cores=4) ## each process may need up to 20Gb of RAM

## transform WIG to BIGWIG format
si <- Seqinfo(seqnames=seqnames(Hsapiens), seqlengths=seqlengths(Hsapiens))
foreach (chr=seqnames(Hsapiens)) %dopar% {
  cat(chr, "\n")
  wigToBigWig(file.path("phastCons30way", sprintf("%s.phastCons30way.wigFix.gz", chr)), seqinfo=si)
}

pkgname <- "phastCons30way.UCSC.hg38"
dir.create(pkgname)

## freeze the GenomeDescription data for Hsapiens

refgenomeGD <- GenomeDescription(organism=organism(Hsapiens),
                                 common_name=commonName(Hsapiens),
                                 provider=provider(Hsapiens),
                                 provider_version=providerVersion(Hsapiens),
                                 release_date=releaseDate(Hsapiens),
                                 release_name=releaseName(Hsapiens),
                                 seqinfo=Seqinfo(seqnames=seqnames(Hsapiens),
                                                 seqlengths=seqlengths(Hsapiens),
                                                 isCircular=isCircular(Hsapiens),
                                                 genome=releaseName(Hsapiens)))

saveRDS(refgenomeGD, file=file.path(pkgname, "refgenomeGD.rds"))

## transform BIGWIG into Rle objects coercing phastCons scores into
## 1-decimal digit raw-encoded values to reduce memory requirements
## in principle deciles of phastCons probabilities should give the
## necessary resolution for the purpose of filtering genetic variants
## on conservation.

## quantizer function for 1-decimal place. it maps input real-valued [0, 1]
## phastCons scores to non-negative integers [0, 255] so that
## each of them can be later coerced into a single byte (raw type).
## quantization is done by rounding to one decimal place,
## and therefore, mapping is restricted to 11 different positive
## integers only [1-11], where the 0 value is kept to code for missingness
## because there is no NA value in the raw class (Sec. 3.3.4 NA handling, R Language Definition)
.quantizer <- function(x) {
  q <- as.integer(sprintf("%.0f", 10*x))
  q <- q + 1L
  q
}
attr(.quantizer, "description") <- "multiply by 10, round to nearest integer, add up one"

## dequantizer function for 1-decimal place. it maps input non-negative integers [0, 255]
## to real-valued phastCons scores, where 0 codes for NA
.dequantizer <- function(q) {
  x <- as.numeric(q)
  x[x == 0] <- NA
  x <- (x - 1) / 10
  x
}
attr(.dequantizer, "description") <- "subtract one integer unit, divide by 10"

nsites <- foreach (chr=seqnames(Hsapiens), .combine='c') %dopar% {
  cat(chr, "\n")
  tryCatch({
    rawscores <- import.bw(BigWigFile(file.path("phastCons30way",
                                                sprintf("%s.phastCons30way.bw", chr))))
    qscores <- .quantizer(rawscores$score)
    max.abs.error <- max(abs(rawscores$score - .dequantizer(qscores)))
    obj <- coverage(rawscores, weight=qscores)[[chr]]
    if (any(runValue(obj) > 0)) {
      runValue(obj) <- as.raw(runValue(obj))
      Fn <- function(x) { warning("no ecdf() function available") ; numeric(0) }
      n <- length(unique(rawscores$score[!is.na(rawscores$score)]))
      if (n > 10) {
        if (n <= 10000) {
          Fn <- ecdf(rawscores$score)
        } else { ## to save space with more than 10,000 different values use sampling
          Fn <- ecdf(sample(rawscores$score[!is.na(rawscores$score)], size=10000, replace=TRUE))
        }
      }
      metadata(obj) <- list(seqname=chr,
                            provider="UCSC",
                            provider_version="03Nov2017",
                            citation=citationdata,
                            download_url=downloadURL,
                            download_date=format(Sys.Date(), "%b %d, %Y"),
                            reference_genome=refgenomeGD,
                            data_pkgname=pkgname,
                            qfun=.quantizer,
                            dqfun=.dequantizer,
                            ecdf=Fn,
                            max_abs_error=max.abs.error)
      saveRDS(obj, file=file.path(pkgname, sprintf("%s.%s.rds", pkgname, chr)))
    }
    nsites <- as.numeric(sum(obj > 0)) ## use 'numeric' to avoid integer overflow
    rm(rawscores, obj)
    gc()
    nsites
  }, error=function(err) {
      message(chr, " ", conditionMessage(err), call.=TRUE)
  })
}

saveRDS(sum(nsites), file=file.path(pkgname, "nsites.rds"))
