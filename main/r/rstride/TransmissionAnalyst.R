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

#############################################################################
# ESTIMATE TRANSMISSION PROBABILITY PARAMETERS TO CALLIBRATE THE MODEL R0  ##
#############################################################################

analyse_transmission_data_for_r0 <- function(project_dir)
{
  
  # terminal message
  smd_print('START TO CALLIBRATE R0')
  
  ##################################
  ## REPRODUCTION NUMBER          ##
  ##################################

  project_summary <- .rstride$load_project_summary(project_dir)
  
  # set the R0 range
  fit_r0_range <- paste0(range(project_summary$r0),collapse='-')
  
  # load the transmission output
  data_transm     <- .rstride$load_aggregated_output(project_dir,'data_transmission',project_summary$exp_id)

  if(length(data_transm) == 1 && is.na(data_transm)){
    smd_print('TRANSMISSION OUTPUT MISSING',WARNING = T)
    return(NA)
  }

  # count secundary infections
  tbl_infections  <- table(data_transm$infector_id)
  sec_transm      <- data.frame(local_id = as.numeric(names(tbl_infections)),
                               sec_cases = as.numeric(tbl_infections))
  
  # add infection time
  infection_time <- data.frame(local_id      = data_transm$local_id,
                               infection_day = data_transm$sim_day,
                               exp_id        = data_transm$exp_id,
                               age           = data_transm$part_age)
  
  sec_transm <- merge(infection_time,sec_transm,all=T)
  sec_transm$sec_cases[is.na(sec_transm$sec_cases)] <- 0
  
  # add R0 and transmission probability from the project_summary
  sec_transm <- merge(sec_transm,project_summary[,c('exp_id','r0','transmission_probability')])
    
  # select index cases
  flag       <- sec_transm$infection_day == 0
  sec_transm <- sec_transm[flag,]
  dim(sec_transm)
  
  # plot(sec_transm$r0,sec_transm$sec_cases)
  # boxplot(sec_cases ~ r0, data = sec_transm)
  # boxplot(sec_cases ~ transmission_probability, data = sec_transm)
  # boxplot(r0 ~ transmission_probability, data = project_summary,add =T ,col=2,border=2)
  # sec_transm$is_adult <- sec_transm$age > 18
  # boxplot(sec_cases ~ transmission_probability + is_adult, data = sec_transm)
  # grid()
  
  # # FIT SECOND ORDER POLYNOMIAL
  #temp <- data.frame(x=sec_transm$transmission_probability, y=sec_transm$sec_cases)
  # mod <- summary(lm(y ~ x + I(x^2), data = temp))
  
  # # FIT FIRST ORDER POLYNOMIAL
  temp <- data.frame(x=sec_transm$transmission_probability, y=sec_transm$sec_cases)
  mod <- summary(lm(y ~ x , data = temp))
  mod
  
  # # logistic model
  # temp <- data.frame(x=sec_transm$transmission_probability, y=log(sec_transm$sec_cases))
  # temp$y[is.infinite(temp$y)] <- NA
  # boxplot(exp(y) ~ x, temp)
  # boxplot((y) ~ x, temp)
  # mod <- summary(lm(y ~ x + I(x^2), data = temp))
  # mod
  # 
  # Get parameters
  fit_b0 <- mod$coefficients[1,1]
  fit_b1 <- mod$coefficients[2,1]
  fit_b2 <- 0
  # fit_b2 <- mod$coefficients[3,1]
  # 
  # 
  # # check R0 limit: prevent upwards parabola and complex root values                
  # R0_limit_fit           <- -fit_b1^2/(4*fit_b2) + fit_b0
  # 
  # # check R0 limit
  # if(R0_limit_fit<0){
  #   smd_print("FITTING NOT SUCCESFULL... THE PARABOLA OPENS UPWARDS",WARNING=TRUE)
  #   smd_print("PLEASE INCREASE THE NUMBER OF REALISATIONS AND/OR TRANSMISSION PROBABILITIES",WARNING=TRUE)
  #   return(.rstride$no_return_value())
  # }
  # 
  # # check R0 limit: prevent complex roots and transmission probability >1
  # transmission_limit_fit <- min(1,.rstride$f_poly_transm(floor(R0_limit_fit),fit_b0,fit_b1,fit_b2),na.rm = T)
  # R0_limit               <- .rstride$f_poly_r0(transmission_limit_fit,fit_b0,fit_b1,fit_b2)
  
  # Reformat fitted values to plot
  R2_poly2 <- round(mod$r.squared,digits=4)
  
  poly_input   <- sort(temp$x)
  R0_poly_fit  <- (.rstride$f_poly_r0(poly_input,fit_b0,fit_b1,fit_b2))
  sec_transm$R0_poly_fit <- round((.rstride$f_poly_r0(sec_transm$transmission_probability,fit_b0,fit_b1,fit_b2)),digits=1)
  
  # set maximum predicted value as R0 limit to prevent extrapolation
  R0_limit <- max(sec_transm$R0_poly_fit)
  
  # fix y-axis limits (default: 0-40)
  y_lim <- range(c(0,5,sec_transm$sec_cases))
  
  # open pdf stream
  .rstride$create_pdf(project_dir,'fit_r0')
  
  # plot secundary cases vs transmission probability 
  boxplot(round(sec_transm$sec_cases,digits=3) ~ round(sec_transm$transmission_probability,digits=3), 
          xlab='Transmission probability',
          ylab='Secundary cases',
          at=sort(round(unique(sec_transm$transmission_probability),digits=3)),
          xlim=range(sec_transm$transmission_probability),
          ylim=y_lim,
          boxwex=0.001
          )
  
  lines(poly_input,R0_poly_fit,type='l',col=3,lwd=4)
  # leg_text_model   <- paste0(c(paste0('b',0:2,': '),'R^2: '),round(c(fit_b0,fit_b1,fit_b2,mod$r.squared),digits=2))
  # leg_text_fitting <- c(leg_text_model,paste0('R0 max:',round(R0_limit,digits=2)),paste0('R0 range: ',fit_r0_range))
  # legend('topleft',legend=leg_text_fitting,cex=0.8,title='b0+b1*x+b2*x^2',ncol=2)
  leg_text_model   <- paste0(c(paste0('b',0:1,': '),'R^2: '),round(c(fit_b0,fit_b1,mod$r.squared),digits=2))
  leg_text_fitting <- c(leg_text_model,paste0('R0 range: ',fit_r0_range))
  legend('topleft',legend=leg_text_fitting,cex=0.8,title='b0+b1*x',ncol=2)
  
  
  # add mean
  mean_sec_cases <- aggregate(sec_cases ~ transmission_probability + R0_poly_fit, data=sec_transm,mean)
  points(mean_sec_cases$transmission_probability,mean_sec_cases$sec_cases,col=4,pch=15)
  legend('top','mean',pch=15,col=4,cex=0.8)
  
  # other x-scale
  boxplot(sec_transm$sec_cases ~ sec_transm$R0_poly_fit,
          xlab='Predicted R0 (using updated transmission parameters)',ylab='Secundary cases',
          at=sort(unique(sec_transm$R0_poly_fit)),
          ylim=y_lim,boxwex=0.05)
  abline(0,1,col=2,lwd=2)
  legend('topleft',legend=leg_text_model,cex=0.8,title='b0+b1*x+b2*x^2')
  legend('topright',legend='x=y',cex=0.8,title='reference',col=2,lwd=2)
  
  points(mean_sec_cases$R0_poly_fit ,mean_sec_cases$sec_cases,col=4,pch=15)
  legend('left','mean',pch=15,col=4,cex=0.8)
  
  
  ###############################
  ## EXPLORE DISEASE FILE       ##
  ###############################
  
  # get disease config filename
  disease_config_file     <- unique(project_summary$disease_config_file)
  
  # load disease config file
  config_disease    <- xmlToList(file.path('data',disease_config_file))
  
  par(mfrow=c(2,2))
  plot(seq_len(length(config_disease$time_asymptomatic))-1,config_disease$time_asymptomatic,xlab='days',ylab='probability',main='time_asymptomatic')
  plot(seq_len(length(config_disease$time_infectious))-1,config_disease$time_infectious,xlab='days',ylab='probability',main='time_infectious')
  plot(seq_len(length(config_disease$start_symptomatic))-1,config_disease$start_symptomatic,xlab='days',ylab='probability',main='start_symptomatic')
  plot(seq_len(length(config_disease$time_symptomatic))-1,config_disease$time_symptomatic,xlab='days',ylab='probability',main='time_symptomatic')
  par(mfrow=c(1,1))
  
  # compare original and new fit
  R0_poly_orig <- .rstride$f_poly_r0(poly_input,
                                     as.numeric(config_disease$transmission$b0),
                                     as.numeric(config_disease$transmission$b1),
                                     as.numeric( config_disease$transmission$b2))
  
  plot(poly_input,R0_poly_orig,
       type='l',lwd=2,
       xlab='transmission probability',
       ylab='secundary cases',
       ylim=y_lim)
  lines(poly_input,R0_poly_fit,col=3,lwd=2)
  # add grid
  abline(v=seq(0,1,0.1),lty=3,col=9)
  abline(h=seq(0,max(y_lim),2),lty=3,col=9)
  # add legend
  legend('topleft',c('original fit','new fit'),
         col=c(1,3),lwd=1,bg= "white")
  
  
  
  ####################################
  ## DISEASE HISTORY MEASLES        ##
  ####################################
  
  if(exists('config_disease$label$pathogen') && config_disease$label$pathogen ==  'measles')
  {
    # # REF:Lesler et al (2009), Lancet Infect Dis
    # # incubation period: lognormal distribution with median 12.5 and dispersion 1.23
    # lognormal distribution,
    days_opt       <- c(0:170)/10                                              # setup time horizon with a small day-interval     
    lnorm_dist     <- dlnorm(days_opt, meanlog = log(12.5), sdlog = log(1.23)) # get lognormal densities
    cum_lnorm_dist <- cumsum(lnorm_dist)/sum(lnorm_dist)                       # get cumulative density
    cum_lnorm_dist <- round(cum_lnorm_dist,digits=2)                           # round 
    cum_lnorm_dist <- data.frame(day=days_opt,prob=cum_lnorm_dist)             # add time horizon 
    
    plot(cum_lnorm_dist$day,cum_lnorm_dist$prob,xlab='day',ylab='probability',main='start symptoms\n(Lesler et al. 2009)')
    
    abline(v=12.5); abline(h=0.5) # median
    abline(h=0.25); abline(v=10.9) # 25% percentile
    abline(h=0.75); abline(v=14.4) # 75% percentile
    
    prob_symp <- cum_lnorm_dist$prob[cum_lnorm_dist$day %in% 0:17]                # store probability for discrete time steps
    prob_symp[1:9] <- 0                                                           # set probability for day 0-8 to "0"
    
    lines(0:17,prob_symp,lwd=4,col=2)
    legend('topleft',c('lesler et al. 2009','STRIDE'),col=1:2,lwd=2)
    if(any(as.numeric(config_disease$start_symptomatic[1:18]) != prob_symp)){
      # command line message
      smd_print('"START SYMPTOMATIC" NOT CONFORM LESLER ET AL 2009.')
      
      config_disease$start_symptomatic[1:18] <- prob_symp
      
      # command line message
      smd_print('UPDATED "START SYMPTOMATIC" ACCORDING LESLER ET AL 2009.')
    }
    
  }
  
  
  # close pdf stream
  dev.off()
  
  ####################################
  ## UPDATE DISEASE CONFIG FILE     ##
  ####################################
 
  variable_param <- .rstride$get_variable_model_param(project_summary)
  
  .rstride$get_unique_param_list(project_summary)
  lapply(project_summary,unique)

  # update transmission param
  config_disease$transmission$b0 <- fit_b0
  config_disease$transmission$b1 <- fit_b1
  config_disease$transmission$b2 <- fit_b2
  
  # add/update meta data
  num_infected_seeds          <- unique(floor(project_summary$seeding_rate * project_summary$population_size))
  par_exp_design              <- .rstride$get_variable_model_param(project_summary) # changing parameters in the exp design
  total_num_index_cases       <- nrow(sec_transm)
  num_rng_seeds               <- length(unique(project_summary$rng_seed))
  dim_exp_design              <- nrow(expand.grid(par_exp_design))
  num_realisations            <- unique(table(project_summary[,colnames(par_exp_design)]))
  
  # if the disease config file has only one value (original state), set value as pathogen
  if(length(config_disease$label) == 1) {
    config_disease$label <- list(pathogen = config_disease$label)
  }
  
  # add all population, contact, disease, model parameters 
  config_disease$label <- unlist(list(pathogen         = config_disease$label$pathogen,
                               num_infected_seeds      = num_infected_seeds,
                               total_num_index_cases   = total_num_index_cases,
                               num_rng_seeds           = num_rng_seeds,
                               dim_exp_design          = dim_exp_design,
                               num_realisations        = num_realisations,
                               fit_r0_limit            = round(R0_limit,digits=2),
                               fit_r0_range            = fit_r0_range,
                               .rstride$get_unique_param_list(project_summary)
                              ),recursive = F)
  
  # update filename: add run_tag
  run_tag                    <- unique(project_summary$run_tag)
  disease_config_update_file <- paste0(run_tag,'_',disease_config_file)
  # update filename: remove file extension
  disease_config_update_file <- sub('.xml','',disease_config_update_file)
  
  # save
  new_disease_config_filename <- .rstride$save_config_xml(config_disease,'disease',file.path(project_dir,disease_config_update_file))
  
  # terminal message
  smd_print('NEW DISEASE CONFIG FILE', disease_config_update_file)
  
  ###############################
  ## TERMINATE PARALLEL NODES  ##
  ###############################
  smd_stop_cluster()
  
  # command line message
  smd_print('R0 CALLIBRATION FINISHED')
  
}

##################################
## POLYNOMIAL HELP FUNCTIONS    ##
##################################

.rstride$f_poly        <- function(x,b0,b1,b2) {b0 + b1*x + b2*(x^2)}
.rstride$f_poly_r0     <- function(x,b0,b1,b2) {b0 + b1*x + b2*(x^2)}
.rstride$f_poly_transm <- function(r0,b0,b1,b2) 
{
  c = b0 - r0
  b = b1
  a = b2
  print(paste(a,b,c))
  d <- b^2 - (4 * a * c)
  
  if(d < 0){
    return(NA)
  }
  
  x1 <- (-b + sqrt(d)) / (2*a)
  x2 <- (-b - sqrt(d)) / (2*a)
  
  return(x1)
}

if(0==1){
  
  xx <- seq(0,0.6,0.1)
  plot(xx,.rstride$f_poly_r0(xx,1.47,35.27,-10.23),type='b',ylim=c(0,20)) #child
  lines(xx,.rstride$f_poly_r0(xx,0.99,22.5,-1.58),type='b',col=2) # adult
  lines(xx,.rstride$f_poly_r0(xx,1.46,35.33,-10.29),type='b',col=3) #child, index
  lines(xx,.rstride$f_poly_r0(xx,1.36,35.92,-11.1),type='b',col=1,lty=2) #child, other rng seed
  lines(xx,.rstride$f_poly_r0(xx,0,41.9,-15.28),type='b',col=1,lty=2) #child, new
  grid()
  abline(h=1)  
}

