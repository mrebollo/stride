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
#  Copyright 2019, Willem L, Kuylen E & Broeckhove J
#############################################################################

source('./bin/socrates/plot_social_contact_matrix.R')

if(0==1) # for debugging
{

  # load help functions
  source('./bin/rstride/Misc.R')
  
  #setwd('..')
  project_summary <- .rstride$load_project_summary(project_dir)
  exp_summary <- project_summary[2,]
  data_dir    <- './data'
  .rstride$plot_contacts(exp_summary,data_dir)
}

#############################################################################
# INSPECT SOCIAL CONTACT PATTERNS                                          ##
#############################################################################

inspect_contact_data <- function(project_dir){
  
  # command line message
  smd_print('INSPECT SOCIAL CONTACT PATTERNS...')
  
  # load summary
  project_summary <- .rstride$load_project_summary(project_dir)
  
  # start slave nodes
  #smd_start_cluster()
  
  # analyse data
  i_exp <- 1
  # parallel processing issues to pass .rstride environment
  foreach(i_exp = 1:nrow(project_summary),
          .packages = 'simid.rtools',
          .export = '.rstride') %do% 
  {  
    # plot contacts
    .rstride$plot_contacts(project_dir,project_summary[i_exp,],'./data')
  }
  
  # end slave nodes
  smd_stop_cluster()
  
  # terminal message
  smd_print('INSPECTION OF SOCIAL CONTACTS PATTERNS COMPLETE')
}

#############################################################################
# FUNCTION TO PLOT SOCIAL CONTACT MATRICES AND COUNTS                      ##
#############################################################################
# exp_summary <- project_summary[i_exp,]; data_dir <- './data'
.rstride$plot_contacts <- function(project_dir,exp_summary,data_dir)
{

  ######################
  ## GET DATA       ##
  ######################

  # load data
  data_cnt      <- .rstride$load_aggregated_output(project_dir,'data_contacts',exp_summary$exp_id)
  data_part     <- .rstride$load_aggregated_output(project_dir,'data_participants',exp_summary$exp_id)

  if(nrow(data_cnt)>0 && nrow(data_part)>0)
  {
    
    ## people without contacts
    dim(data_part)[1] - length(unique(data_cnt$local_id))

    ## merge school and college contacts
    data_cnt$cnt_school <- as.numeric(data_cnt$cnt_school + data_cnt$cnt_college > 0)
        
    ## employed and student population
    data_part$employed <- data_part$workplace_id != 0
    data_part$student  <- data_part$school_id != 0 | data_part$college_id !=0
    
    ## SETTINGS 
    L <- max(c(80,data_part$part_age))
    num_days      <- exp_summary$num_days
    
    # open pdf stream  
    exp_tag <- .rstride$create_exp_tag(exp_summary$exp_id)
    .rstride$create_pdf(project_dir,paste0(exp_tag,'_cnt_patterns'),10,5)
    #par(mfrow=c(2,2))
    
    ## TOTAL
    mij_total  <- .rstride$plot_cnt_matrix(data_cnt,data_part,'total',L,num_days)
    
    ## HOUSEHOLD
    mij_hh     <- .rstride$plot_cnt_matrix(data_cnt[data_cnt$cnt_home==1,],data_part,'household',L,num_days)
    
    ## SCHOOL
    mij_school <- .rstride$plot_cnt_matrix(data_cnt[data_cnt$cnt_school==1,],data_part[data_part$student==T,],'school',L,num_days)
    
    ## WORK
    mij_work   <- .rstride$plot_cnt_matrix(data_cnt[data_cnt$cnt_work==1,],data_part[data_part$employed==T,],'work',L,num_days)
    
    ## PRIMARY COMMUNITY
    mij_prim_comm <- .rstride$plot_cnt_matrix(data_cnt[data_cnt$cnt_prim_comm==1,],data_part,'prim_comm',L,num_days)
    
    ## SECUNDARY COMMUNITY
    mij_sec_comm <- .rstride$plot_cnt_matrix(data_cnt[data_cnt$cnt_sec_comm==1,],data_part,'sec_comm',L,num_days)
    
    #dev.off()
    
    ref_data_tag <- 'ref_fl2010'
    if(grepl('15touch',exp_summary$age_contact_matrix_file)){
      #ref_data_tag <- 'ref_fl2010_15touch'
      smd_print("NO REFERENCE 15_touch CONTACT DATA AVAIABLE",WARNING = TRUE)
    }
    
    # LOAD SURVEY DATA FROM FLANDERS AND FULLY CONNECTED HOUSEHOLDS
    survey_data <- xmlToList(file.path(data_dir,exp_summary$age_contact_matrix_file))
    names(survey_data)
    
    get_survey_data <- function(cluster_type){
      survey_cluster     <- unlist(survey_data[[cluster_type]])
      flag_rate          <- grepl('contact.rate',names(survey_cluster))
      survey_mij_cluster <- matrix(as.numeric(survey_cluster[flag_rate]),nrow=sum(flag_rate))
      return(survey_mij_cluster)
    }
    
    survey_mij_hh         <- get_survey_data('household')
    survey_mij_school     <- get_survey_data('school')
    survey_mij_work       <- get_survey_data('work')
    survey_mij_community  <- get_survey_data('secondary_community')
    survey_mij_total      <- get_survey_data('regular_weekday')
    
    survey_mij_school_weekend     <- survey_mij_school*0
    survey_mij_work_weekend       <- survey_mij_work*0
    survey_mij_community_weekend  <- get_survey_data('primary_community')
    survey_mij_total_weekend      <- get_survey_data('regular_weekend')
    
    ## COMPARE
    par(mfrow=c(2,3))
    
    plot(rowSums(survey_mij_total),main='total',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,40))
    lines(rowSums(survey_mij_total_weekend),main='total',xlab='age',ylab='contacts',type='l',lty=2)
    points(rowSums(mij_total,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    
    plot(rowSums(survey_mij_hh),main='household',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,5))
    points(rowSums(mij_hh,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    
    plot(rowSums(survey_mij_school),main='school',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,20))
    lines(rowSums(survey_mij_school_weekend),type='l',lty=2)
    points(rowSums(mij_school,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    
    plot(rowSums(survey_mij_work),main='work',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,20))
    lines(rowSums(survey_mij_work_weekend),type='l',lty=2)
    points(rowSums(mij_work,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    
    plot(rowSums(survey_mij_community),main='primary community',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,25))
    lines(rowSums(survey_mij_community_weekend),type='l',lty=2)
    points(rowSums(mij_prim_comm,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    
    plot(rowSums(survey_mij_community),main='secondary community',xlab='age',ylab='contacts',type='l',ylim=c(-0.1,25))
    lines(rowSums(survey_mij_community_weekend),type='l',lty=2)
    points(rowSums(mij_sec_comm,na.rm=T),col=2)
    legend('topright',c('week','weekend','model'),col=c(1,1,2),lty=c(1,2,0),pch=c(-1,-1,1),cex=0.8,title=ref_data_tag)
    par(mfrow=c(1,1))
    
    dev.off() # close pdf stream
    
    # new
    .rstride$create_pdf(project_dir,paste0(exp_tag,'_cnt_transm_probability'))
    par(mfrow=c(2,2))
    cnt_location_opt <- c('cnt_home', 'cnt_school', 'cnt_work', 'cnt_prim_comm', 'cnt_sec_comm')
    for(i_cnt in cnt_location_opt){
      flag <- data_cnt[,i_cnt] == 1
      if(any(flag))
        boxplot(cnt_prob ~ part_age, data=data_cnt[flag,],
                main=paste(i_cnt, '[CNT]'),xlab='age',ylab='contact probability')
    }
    
    for(i_cnt in cnt_location_opt){
      flag <- data_cnt[,i_cnt] == 1
      if(any(flag))
        boxplot(trm_prob ~ part_age, data=data_cnt[flag,],
                main=paste(i_cnt, '[TRM]'),xlab='age',ylab='transmission probability')
    }
    
    dev.off() # close pdf stream

    ## OTHER MATRICES ####
    
    age_cat_breaks <- c(0,19,110)
    plot_socrates_all(data_cnt,data_part,age_cat_breaks,project_dir,paste0(exp_tag,'_AG2'),exp_summary$start_date)
    
    # results by age group
    age_cat_breaks <- c(0,19,36,66,110)
    plot_socrates_all(data_cnt,data_part,age_cat_breaks,project_dir,paste0(exp_tag,'_AG4'),exp_summary$start_date)
   
  } # end if dim(data)...
} # end function

#################################  OTHER HELP FUNCTIONS  #################################




## HELP FUNCTION: RESHAPE DATA AND PLOT
#f_data_cnt = data_cnt;f_data_part=data_part_age_cat;tag='total';L;num_days
.rstride$plot_cnt_matrix <- function(f_data_cnt,f_data_part,tag,L,num_days)
{
  
  # select participants
  data_cnt_flag <- f_data_cnt$local_id %in% f_data_part$local_id 
  
  # temporary max age
  L_temp <- max(f_data_cnt$part_age,L,f_data_cnt$cnt_age)+1
  
  # count contacts
  mij_tbl <- table(f_data_cnt$part_age,f_data_cnt$cnt_age)
  row_ind <- as.numeric(row.names(mij_tbl)) +1 # age 0 == index 1
  col_ind <- as.numeric(colnames(mij_tbl))  +1 # age 0 == index 1
  mij <- matrix(0,L_temp,L_temp)
  mij[row_ind,col_ind] <- mij_tbl
  
  # count participant per age
  if(sum(mij)==0)
  {
    row_ind <- 1:(L+1)
    col_ind <- 1:(L+1)
  }
  p_ages_tbl              <- table(f_data_part$part_age)
  
  row_ind <- as.numeric(names(p_ages_tbl)) +1
  p_ages <- matrix(0,L_temp,1)
  p_ages[row_ind] <- p_ages_tbl
  
  # remove age>L (age_column L+1)
  mij <- mij[1:(L+1),1:(L+1)]
  p_ages <- p_ages[1:(L+1)]
  
  # adjust for number of participants (if age is present)
  ages_present <- p_ages>0
  p_ages[ages_present]
  
  # contacts/participant
  for(j in 1:(L+1))
  {
    if(p_ages[j]>0)
    {
      mij[j,] <- mij[j,] / p_ages[j]
    }
  }
  
  # account for multiple days
  mij <- mij/num_days
  
  # set NA if participant age is not present in provided data
  #mij[,!ages_present] <- NA
  mij[!ages_present,] <- NA
  
  
  # plot matrix 
  g_matrix <- .rstride$plot_cnt_matrix_ggplot(mij,tag,FALSE)
  
  # plot number of contacts
  g_count  <- .rstride$plot_cnt_count_ggplot(f_data_cnt,f_data_part,L,num_days,tag)
  
  grid.arrange(g_matrix, g_count, ncol = 2)
  
  return(mij)
}

## HELP FUNCTION: PLOT CNT MATRIX
.rstride$plot_cnt_matrix_ggplot <- function(mij,title,bool_contour)
{
  ## remove small numbers
  mij[mij < quantile(mij,0.1,na.rm=T)] <- 0
  
  # Function to rescale z according to quantiles
  mij_ecdf <- ecdf(mij)
  
  # Covert matrix into data.frame for plotting with ggplot
  ggplot_data <- expand.grid(x = 0:(nrow(mij) - 1), y = 0:(nrow(mij) - 1))
  ggplot_data <- within(ggplot_data, {
    z <- as.vector(mij)
    z.rescaled <- mij_ecdf(mij)
  })
  
  
  z.breaks <- signif(unique(quantile(ggplot_data$z, prob = seq(from = 0, to = 1, length = 5),na.rm=T)), digits = 1)
  z.breaks.rescaled <- mij_ecdf(z.breaks)
  
  # Create the plot
  g <- ggplot(data = ggplot_data, mapping = aes(x = x, y = y, fill = z.rescaled, z = z.rescaled)) +
    geom_raster() +
    guides(colour=guide_legend("",order = 0),
           fill = guide_colourbar(order = 1))  +
    scale_fill_distiller(
      palette = "YlOrRd",
      breaks = z.breaks.rescaled,
      labels = z.breaks,
      name = 'Rate') +
    labs(x = "Age", y = "Age of contacts") +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) +
    coord_fixed() +
    theme_bw() +
    ggtitle(title) +
    theme(legend.justification = c(1, 1),
          legend.position = 'right',
          legend.text     = element_text(size=18),
          legend.title    = element_text(size=18),
          axis.text       = element_text(size=20),
          axis.title      = element_text(size=20),
          plot.title      = element_text(size=40, face="bold",hjust = 0.5),
          panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank()
    ) 
  
  # add missing ages?
  if(any(is.na(ggplot_data$z.rescaled))){
    g + geom_tile(data = subset(ggplot_data,  is.na(z.rescaled)), aes(colour = 'No data'),
                  linetype = 0, fill = "grey50")
  }
    # Add contour lines?
  if (bool_contour) {
    g + geom_contour(breaks = z.breaks, colour = "black", size = 0.2)
  } 
  
  # return
  return(g)
}

## HELP FUNCTION: PLOT CNT COUNT
.rstride$plot_cnt_count_ggplot <- function(f_data_cnt,f_data_part,L,num_days,title){
  
  if(nrow(f_data_cnt)==0){
    ggplot_data <-data.frame(local_id = -1,
                             part_age = f_data_part$part_age,
                             cnt_count = 0)
  } else{
    # Covert matrix into data.frame for plotting with ggplot
    ggplot_data        <- data.frame(table(f_data_cnt$local_id)/ num_days) 
    names(ggplot_data) <- c('local_id','cnt_count')
    ggplot_data <- merge(ggplot_data,f_data_part)
  }
  
  # remove oldest ages
  ggplot_data <- ggplot_data[ggplot_data$part_age<=L,]
  
  # average count per age
  cnt_age_mean <- aggregate(.~ part_age , data = ggplot_data[,2:3] ,mean) 
  
  # create plot
  g_plot <- ggplot(ggplot_data, aes(x=part_age, y=cnt_count)) + 
    aes(group = part_age) +
    geom_boxplot() +
    labs(x = "Age", y = "Count") +
    theme_bw() +
    ggtitle(title) +
    geom_line(data = cnt_age_mean, aes(x=part_age, y=cnt_count,group = 1),
              size=2, colour="red") +
    theme(legend.justification = c(1, 1),
          legend.position = 'right',
          legend.text = element_text(size=18),
          legend.title = element_text(size=18),
          axis.text=element_text(size=20),
          axis.title=element_text(size=20),
          plot.title = element_text(size=40, face="bold",hjust = 0.5)
    )
  return(g_plot)
  
}



