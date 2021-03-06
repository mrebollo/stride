#############################################################################
#  This file is part of the Stride software. 
#  It is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by 
#  the Free Software Foundation, either version 3 of the License, or any 
#  later version.
#  The software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  You should have received a copy of the GNU General Public License,
#  along with the software. If not, see <http://www.gnu.org/licenses/>.
#  see http://www.gnu.org/licenses/.
#
#
#  Copyright 2020, Willem L, Kuylen E & Broeckhove J
#############################################################################
#
# MODEL SUMMARY EXPLORATION
# - input-output behavior
# - transmission events and context
#
#############################################################################

inspect_summary <- function(project_dir)
{
  
  # load project output summary
  project_summary    <- .rstride$load_project_summary(project_dir)
  
  # retrieve all variable model parameters
  input_opt_design   <- .rstride$get_variable_model_param(project_summary)
  
  # stop if there are no different input parameter values
  if(nrow(input_opt_design)<=1){
    
    # terminal message
    smd_print('NO VARYING INPUT PARAMETERS IN THE SUMMARY DATA')
    
    # stop
    return(.rstride$no_return_value())
  }
  
  # calculate values and labels for the second y-axis [cases vs. incidence]
  pop_size          <- median(project_summary$num_cases / project_summary$AR)
  ticks_name        <- pretty(project_summary$num_cases/pop_size)
  tick_value        <- ticks_name*pop_size
  
  # OPEN PDF STREAM
  .rstride$create_pdf(project_dir,'summary_inspection',10,7)
  
  # loop over the changing input parameters => plot cases and incidence
  #par(mfrow=c(2,2))
  par(mar = c(10, 4, 4, 4) + 0.3)  # Leave space for 3rd axis
  for(i in 1:ncol(input_opt_design)){
    boxplot(num_cases ~ project_summary[,colnames(input_opt_design)[i]],
            data = project_summary,
            xlab = colnames(input_opt_design)[i],
            ylab = '',cex.axis=0.8,las=2)
    axis(4, at = tick_value , labels = ticks_name )
    mtext("incidence", side=4, line=2,cex=0.9)
    mtext("number of cases", side=2, line=2,cex=0.9)
  }
  
  par(mar = c(10, 4, 1, 4) + 0.3)  # Leave space for 3rd axis
  boxplot(as.formula(paste("num_cases ~ interaction(",paste(colnames(input_opt_design),collapse=','),',drop=T)')),
          data = project_summary,
          ylab = '',
          las=2,
          cex.axis=0.8)
  axis(4, at = tick_value , labels = ticks_name )
  mtext("incidence", side=4, line=2,cex=0.9)
  mtext("total number of cases", side=2, line=2,cex=0.9)
  
  # exclude 'start date' from the overview, if present in the experimental design
  if(('start_date' %in% colnames(input_opt_design))){
    par(mar = c(10, 4, 1, 4) + 0.3)  # Leave space for 3rd axis
    param_selection <- colnames(input_opt_design)[!grepl('start_date',colnames(input_opt_design))]
    boxplot(as.formula(paste("num_cases",paste(param_selection,collapse='+'),sep="~")),
            data = project_summary,
            ylab = '',
            las=2,
            cex.axis=0.8)
    axis(4, at = tick_value , labels = ticks_name )
    mtext("incidence", side=4, line=2,cex=0.9)
    mtext("total number of cases", side=2, line=2,cex=0.9)
  }
  
  
  ## SECONDARY CASES ##
  
  # get infected seeds per simulation  
  project_summary$num_infected_seeds <- floor(project_summary$population_size * project_summary$seeding_rate)
  
  # secondary cases  
  project_summary$num_sec_cases     <- project_summary$num_cases - project_summary$num_infected_seeds
  project_summary$avg_num_sec_cases <- project_summary$num_sec_cases / project_summary$num_infected_seeds
  
  
  # plot
  sec_cases_formula  <- as.formula(paste('avg_num_sec_cases ~ interaction(',paste(colnames(input_opt_design),collapse=' , '),',drop=TRUE)'))
  bxplot <- boxplot(sec_cases_formula, 
                    data=project_summary,
                    ylab = '',
                    xlab=paste(colnames(input_opt_design)),
                    las=2,
                    cex.axis=0.8)
  mtext("Sec. cases per index case", side=2, line=2,cex=0.9)
  grid()
  
  sec_cases_mean <- aggregate(sec_cases_formula,data=project_summary,mean)
  if(all(sec_cases_mean[,1] == bxplot$names)){
    points(1:nrow(sec_cases_mean),sec_cases_mean$avg_num_sec_cases,pch=4,lwd=2)
    legend('topleft','mean',pch=4,col=1,cex=0.8)
  }
  
  ## SUBSETS
  num_subsets <- 10
  project_summary$subset_id <- sample(num_subsets,nrow(project_summary),replace = T)
  sec_cases_formula  <- as.formula(paste('avg_num_sec_cases ~ interaction(subset_id,',paste(colnames(input_opt_design),collapse=' , '),',drop=TRUE)'))
  bxplot <- boxplot(sec_cases_formula, 
                    data=project_summary,
                    ylab = '',
                    xlab=paste(colnames(input_opt_design),collapse=' , '),
                    las=2,
                    cex.axis=0.8)
  mtext("Sec. cases per index case", side=2, line=2,cex=0.9)
  grid()
  
  sec_cases_mean <- aggregate(sec_cases_formula,data=project_summary,mean)
  points(which(!is.na(bxplot$stats[1,])),sec_cases_mean$avg_num_sec_cases,pch=4,lwd=2)
  abline(v=(0:20)*num_subsets+0.5)
  legend('topleft','mean',pch=4,col=1,cex=0.8)
  title(paste('subset size:',mean(bxplot$n)))
  
  dev.off()
  
  # terminal message
  smd_print('INSPECTION OF SUMMARY DATA COMPLETE')
  
}

## HELP FUNCTION
.rstride$get_variable_model_param <- function(project_summary){
  
  input_opt    <- .rstride$get_unique_param_list(project_summary)
  input_opt    <- input_opt[lapply(input_opt,length)>1]
  
  # get parameter combinations
  input_opt_design <- unique(project_summary[,names(input_opt)])
  
  # with only one parameter, convert vector into matrix
  if(length(input_opt)==1){
    input_opt_design <- as.matrix(data.frame(input_opt))
  }
  
  # with only identical parameters, use the r0
  if(length(input_opt)==0){
    input_opt_design <- as.matrix(data.frame(r0=unique(project_summary$r0)))
  }
  
  return(input_opt_design)
  
}

## HELP FUNCTION
.rstride$get_unique_param_list <- function(project_summary){
  
  col_output <- c('run_time', 'total_time', 'num_cases', 'AR' )
  col_extra  <- c('rng_seed','output_prefix','transmission_probability','exp_id') 
  col_input  <- !(names(project_summary) %in% c(col_output,col_extra))
  
  # get unique values per parameter
  input_opt    <- lapply(project_summary[,col_input],unique)
  
  # return
  return(input_opt)
}
