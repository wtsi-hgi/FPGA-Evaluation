library(ggplot2)
library(reshape)

root_dir <- "~/projects/vareval/syndip/final-eval"
subdirs = list.files(root_dir)

for (i in 1:length(subdirs)) {
  dir = subdirs[i]
    depth = strsplit(dir, "-")[[1]][1]
      files = list.files(path = paste(root_dir, dir, sep="/"), pattern = "\\.summary$")
        for (j in 1:length(files)){
	    file = files[j]
	        file_fields = unlist(strsplit(file, "[.]"))

    sample = file_fields[2]
        vc = file_fields[3]
	    if (vc=="bam_to_gvcf")
	          vc="Native DRAGEN"
		      if (vc=="bam_to_gvcf_gatk")
		            vc="GATK on DRAGEN"
			        if (vc=="fastq_to_dragen_cram_to_gatk_vcf")
				      vc="GATK on FCE with DRAGEN alignments"
				          if (vc=="fastq_to_bwa_cram_to_gatk_vcf")
					        vc="GATK on FCE with BWA alignments"
						    if (vc=="v070")
						          vc="DeepVariant with BWA alignments"
							      if (vc=="gcp_gatk")
							            vc="GATK in GCP with BWA alignments"

    eval <- read.delim(paste(root_dir, dir, file, sep="/"), header = FALSE)
        eval <- cbind(rep(sample, length(rownames(eval))), rep(vc, length(rownames(eval))), eval)
	    colnames(eval) <- c("sample","vc_tool", "eval_type", "var_type", "metric", depth)

    if (j==1)
          eval_types <- eval
	      else
	            eval_types <- rbind(eval, eval_types)
		      }
		        if (i==1)
			    eval_all <- eval_types
			      else {
			          eval_all <- cbind(eval_all, eval_types[,ncol(eval_types)])
				      colnames(eval_all)[ncol(eval_all)] = depth
				        }
					}

eval_all <- eval_all[,c(1:5, 11, 6:10)]

eval_all <- eval_all[,1:10] #remove 5x
eval_melt <- melt(eval_all, id.vars = c("sample", "vc_tool", "eval_type", "var_type","metric"), variable_name = "depth")

eval_melt$var_type_ord = factor(eval_melt$var_type, levels = c("SNP", "INDEL"))
eval_melt$metric_ord = factor(eval_melt$metric, levels = c("FPpM", "%FNR"))

pdf("CHM1-CHM13-2.evaluation.pdf", height=10, width = 15)
rows_to_plot <- which(eval_melt$sample=="CHM1-CHM13-2" & eval_melt$metric %in% c("FPpM","%FNR") & eval_melt$eval_type=="rtgeval-gt")

ggplot(eval_melt[rows_to_plot,], aes(x=depth, y=value, fill=vc_tool)) +
  geom_bar(stat="identity", position=position_dodge()) +
    facet_grid( metric_ord ~ var_type_ord, scales="free") +
      xlab("Depth") + ylab("Evaluation metric") +
        scale_fill_brewer(name="VC pipeline", palette="Dark2") +
	  ggtitle("Sample CHM1-CHM13-2")

dev.off()

pdf("CHM1-CHM13-3.evaluation.pdf", height=10, width = 15)
rows_to_plot <- which(eval_melt$sample=="CHM1-CHM13-3" & eval_melt$metric %in% c("FPpM","%FNR") & eval_melt$eval_type=="rtgeval-gt")

ggplot(eval_melt[rows_to_plot,], aes(x=depth, y=value, fill=vc_tool)) +
  geom_bar(stat="identity", position=position_dodge()) +
    facet_grid( metric_ord ~ var_type_ord, scales="free") +
      xlab("Depth") + ylab("Evaluation metric") +
        scale_fill_brewer(name="VC pipeline", palette="Dark2") +
	  ggtitle("Sample CHM1-CHM13-3")

dev.off()