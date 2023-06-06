##SOURCE: https://github.com/bioinform/somaticseq/blob/seqc2/utilities/dockered_pipelines/alignments/singleIndelRealign.sh

#!/bin/bash
# Use getopt instead of getopts for long options

set -e

OPTS=`getopt -o o: --long output-dir:,tumor-bam:,genome-reference:,selector:,threads:,extra-arguments:,out-script:,standalone, -n 'singleIndelRealign.sh'  -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

#echo "$OPTS"
eval set -- "$OPTS"

MYDIR="$( cd "$( dirname "$0" )" && pwd )"

timestamp=$( date +"%Y-%m-%d_%H-%M-%S_%N" )
threads=1

while true; do
    case "$1" in
        -o | --output-dir )
            case "$2" in
                "") shift 2 ;;
                *)  outdir=$2 ; shift 2 ;;
            esac ;;
            
        --tumor-bam )
            case "$2" in
                "") shift 2 ;;
                *)  tumorBam=$2 ; shift 2 ;;
            esac ;;

        --genome-reference )
            case "$2" in
                "") shift 2 ;;
                *)  HUMAN_REFERENCE=$2 ; shift 2 ;;
            esac ;;

        --selector )
            case "$2" in
                "") shift 2 ;;
                *)  SELECTOR=$2 ; shift 2 ;;
            esac ;;

        --threads )
            case "$2" in
                "") shift 2 ;;
                *)  threads=$2 ; shift 2 ;;
            esac ;;

        --extra-arguments )
            case "$2" in
                "") shift 2 ;;
                *)  extra_arguments=$2 ; shift 2 ;;
            esac ;;

        --out-script )
            case "$2" in
                "") shift 2 ;;
                *)  out_script_name=$2 ; shift 2 ;;
            esac ;;

        --standalone )
            standalone=1 ; shift ;;

        -- ) shift; break ;;
        * ) break ;;
    esac
done

logdir=${outdir}/logs
mkdir -p ${logdir}

if [[ ${out_script_name} ]]
then
    out_script="${out_script_name}"
else
    out_script="${logdir}/singleIndelRealign.${timestamp}.cmd"    
fi


if [[ $standalone ]]
then
    echo "#!/bin/bash" > $out_script
    echo "" >> $out_script
    echo "#$ -o ${logdir}" >> $out_script
    echo "#$ -e ${logdir}" >> $out_script
    echo "#$ -S /bin/bash" >> $out_script
    echo '#$ -l h_vmem=8G' >> $out_script
    echo 'set -e' >> $out_script
fi

echo "" >> $out_script


if [[ ${SELECTOR} ]]
then
    selector_text="-L /mnt/${SELECTOR}"
fi


echo "docker run --rm -v /:/mnt -u $UID broadinstitute/gatk3:3.8-0 \\" >> $out_script
echo "java -Xmx8g -jar /usr/GenomeAnalysisTK.jar \\" >> $out_script
echo "-T RealignerTargetCreator \\" >> $out_script
echo "-R /mnt/${HUMAN_REFERENCE} \\" >> $out_script
echo "-I /mnt/${tumorBam} \\" >> $out_script
echo "-nt ${threads} \\" >> $out_script
echo "${selector_text} \\" >> $out_script
echo "-o /mnt/${outdir}/indelRealign.${timestamp}.intervals" >> $out_script

echo "" >> $out_script

tumorBamFileName=`basename ${tumorBam}`
tumorOut=${tumorBamFileName%.bam}.indelRealigned.bam

echo "docker run --rm -v /:/mnt -u $UID broadinstitute/gatk3:3.8-0 \\" >> $out_script
echo "java -Xmx8g -jar /usr/GenomeAnalysisTK.jar \\" >> $out_script
echo "-T IndelRealigner \\" >> $out_script
echo "-R /mnt/${HUMAN_REFERENCE} \\" >> $out_script
echo "-I /mnt/${tumorBam} \\" >> $out_script
echo "-targetIntervals /mnt/${outdir}/indelRealign.${timestamp}.intervals \\" >> $out_script
echo "${selector_text} \\" >> $out_script
echo "${extra_arguments} \\" >> $out_script
echo "-o /mnt/${outdir}/${tumorOut}" >> $out_script


echo "" >> $out_script

echo "mv ${outdir}/${tumorOut%.bam}.bai ${outdir}/${tumorOut}.bai" >> $out_script
