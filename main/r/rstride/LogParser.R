#!/usr/bin/env Rscript
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
#  Copyright 2019, Willem L, Kuylen E & Broeckhove J
#############################################################################
# 
# Helpfunction(s) to parse the log file(s)
#
#############################################################################

##################################
## PARSE LOGFILE               ##
##################################

"DEVELOPMENT CODE"
if(0==1){
  
  #f_exp_dir <- file.path(output_dir,output_exp_dirs[i_exp])
  f_exp_dir <- file.path(project_dir,'exp0001')
  contact_log_filename <- file.path(f_exp_dir,'contact_log.txt')
  
  
}

.rstride$parse_contact_logfile <- function(contact_log_filename,exp_id)
{
  
  # terminal message
  cat("PARSING LOGFILE:",contact_log_filename,fill=TRUE)
  
  # count the maximum number of columns in the logfile
  data_ncol <- max(count.fields(contact_log_filename, sep = " "))
  
  # load log file using a specified number of columns and fill empty columns
  # By default, the first record determines the number of columns, so info might get lost
  data_log  <- read.table(contact_log_filename, sep=' ',fill=T,col.names = paste0("V", seq_len(data_ncol)),stringsAsFactors = F)
  
  # experiment output directory
  exp_dir <- dirname(contact_log_filename)
  
  # initialise output variables
  rstride_out <- list()
  
  # Parse log file using the following tags tags: 
  # - PART    participant info
  # - PRIM    seed infection
  # - TRAN    transmission event
  # - CONT    contact event
  # - VACC    additional immunization
  # 
  # note:
  # - drop the first column with the log tag
  
  ######################
  ## PARTICIPANT DATA ##
  ######################
  if(any(data_log[,1] == "[PART]"))
  {
    header_part         <- c('local_id', 'part_age', 'household_id', 'school_id', 'college_id','workplace_id',
                             'is_susceptible','is_infected','is_infectious','is_recovered','is_immune',
                             'start_infectiousness','start_symptomatic','end_infectiousness','end_symptomatic',
                             'household_size','school_size','college_size','workplace_size','primarycommunity_size','secundarycommunity_size','is_teleworking')
    data_part           <- data_log[data_log[,1] == "[PART]",seq_len(length(header_part))+1]
    names(data_part)    <- header_part
    data_part[1,]
    
    # set 'true' and 'false' in the R-format
    data_part[data_part=="true"] <- TRUE
    data_part[data_part=="false"] <- FALSE
    
    # make sure, all values (except the booleans) are stored as integers
    col_non_numeric <- which(grepl('is_',header_part))
    data_part[,-col_non_numeric] <- data.frame(apply(data_part[,-col_non_numeric], 2, as.double))
    
    # add exp_id
    data_part$exp_id <- exp_id
    
    # save
    # save(data_part,file=file.path(exp_dir,'data_participants.RData'))
    rstride_out$data_participants = data_part
  } else {
    rstride_out$data_participants = NA
  }
  
  
  #######################
  ## TRANSMISSION DATA ##
  #######################
  if(any(c("[PRIM]","[TRAN]") %in% data_log[,1]))
  {
    header_transm       <- c('local_id', 'infector_id','part_age',
                             'infector_age','cnt_location','sim_day','id_index_case',
                             'start_infectiousness','end_infectiousness','start_symptoms','end_symptoms',
                             'infector_is_symptomatic')
    data_transm         <- data_log[data_log[,1] == "[PRIM]" | data_log[,1] == "[TRAN]",seq_len(length(header_transm))+1]
    names(data_transm)  <- header_transm
    data_transm[100,]
    
    # make sure, all values are stored as integers
    if(any(apply(data_transm, 2, typeof) != 'integer')){
      location_col <- names(data_transm) %in% c('cnt_location','infector_is_symptomatic')
      if(nrow(data_transm)>1){
        data_transm[,!location_col] <- data.frame(apply(data_transm[,!location_col], 2, as.double))
      } else {
        data_transm[,!location_col] <- c(apply(data_transm[,!location_col], 2, as.double))
      }
    }
    
    # set 'true' and 'false' in the R-format
    data_transm$infector_is_symptomatic <- as.logical(data_transm$infector_is_symptomatic)
    
    # set local_id and cnt_location from the seed infected cases to NA (instead as -1)
    data_transm[data_transm == -1]   <- NA
    data_transm$cnt_location[data_transm$cnt_location == '<NA>'] <- NA
    
    # add exp_id
    data_transm$exp_id <- exp_id
    
    # save
    # save(data_transm,file=file.path(exp_dir,'data_transmission.RData'))
    rstride_out$data_transmission = data_transm
  } else {
    rstride_out$data_transmission = NA
  }
  
  ######################
  ## CONTACT DATA     ##
  ###################### 
  if(any(data_log[,1] == "[CONT]"))
  {
    header_cnt          <- c('local_id', 'part_age', 'cnt_age', 'cnt_home', 'cnt_school', 
                             'cnt_college','cnt_work', 'cnt_prim_comm', 'cnt_sec_comm', 
                             'sim_day', 'cnt_prob', 'trm_prob','part_sympt','cnt_sympt')
    data_cnt            <- data_log[data_log[,1] == "[CONT]",seq_len(length(header_cnt))+1]
    names(data_cnt)     <- header_cnt
    data_cnt[1,]
    
    # convert text into boolean
    data_cnt$part_sympt <- as.numeric(data_cnt$part_sympt == 'true')
    data_cnt$cnt_sympt  <- as.numeric(data_cnt$cnt_sympt == 'true')
    
    # make sure, all values are stored as integers
    data_cnt <- data.frame(apply(data_cnt,  2, as.double))
    dim(data_cnt)
    
    # add exp_id
    data_cnt$exp_id <- exp_id
    
    # save
    # save(data_cnt,file=file.path(exp_dir,'data_contacts.RData'))
    rstride_out$data_contacts = data_cnt
  } else {
    rstride_out$data_contacts = NA
  }
  
  ######################
  ## VACCINATION DATA ##
  ###################### 
  if(any(data_log[,1] == "[VACC]"))
  {
    header_cnt          <- c('local_id', 'part_age', 'pool_type', 'pool_id', 'pool_has_infant', 'sim_day')
    data_vacc           <- data_log[data_log[,1] == "[VACC]",seq_len(length(header_cnt))+1]
    names(data_vacc)    <- header_cnt
    data_vacc[1,]
    
    # make sure, all values are stored as integers
    pool_type_col <- names(data_vacc) %in% c('pool_type','pool_has_infant')
    data_vacc[,!pool_type_col] <- data.frame(apply(data_vacc[,!pool_type_col], 2, as.integer))
    dim(data_vacc)
    
    # add exp_id
    data_vacc$exp_id <- exp_id
    
    # save
    # save(data_vacc,file=file.path(exp_dir,'data_vaccination.RData'))
    rstride_out$data_vaccination = data_vacc
  } else {
    rstride_out$data_vaccination = NA
  }
  
  # save list with all results
  # save(rstride_out,file=file.path(exp_dir,'output_log_parsed.RData'))
  
  # terminal message
  cat("LOG PARSING COMPLETE",fill=TRUE)
  
  # return
  return(rstride_out)
}