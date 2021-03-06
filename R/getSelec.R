
#' Title
#'
#' @param age vector of ages
#' @param psel selectivity parameters
#' @param Smin Minimum caught age
#' @param Smax maximum age to model seperately
#'
#' @return
#' @export
#'
#' @examples
#'

getSelec <- function(age,psel, Smin, Smax){
#
#psel <- pseltmp
psel<- c(0,psel)

nage <- length(age)

selectivity <- rep(NA,nage)

pmax <- max(cumsum(psel))

for(j in 1:nage){ # Find the  selectivity
  if (age[j] < Smin){
    selectivity[j] = 0;
    ptmp <- 0
  }
  if (age[j] == Smin){
    ptmp = psel[j-Smin]


    selectivity[j] = exp(ptmp-pmax)

  }
  if (age[j] > Smin & (age[j] <= Smax)){
    ptmp = psel[j-Smin]+ptmp;

    selectivity[j] = exp(ptmp-pmax);
  }
  if(age[j] > (Smax)){
    selectivity[j] = selectivity[Smax+1];
  }
 # print(ptmp-pmax)
}


return(selectivity)
}
