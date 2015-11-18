upload_oom_heapdump_to_server() {
heapusername=$1
heappassword=$2
endpoint=$3
if [ -z "$heapusername" ]; then
   echo "heap user is required please set"
   exit
fi
#checking heappassword
if [ -z "$heappassword" ]; then
   echo "heappassword is required please set"
   exit
fi
#checking server url
echo "Heapd dump endpoint ist ${endpoint}"
if [ -z "$endpoint" ]; then
   echo "heap dump endpoint is required please set"
   exit
fi

    heapdumpfile=$PWD/oom_heapdump.hprof
    echo "Compressing files"
    gzip $heapdumpfile
     echo "Start Upload ${heapdumpfile}"
     curl -X POST -H "Content-Type: multipart/form-data" -F "file=@${heapdumpfile}.gz" ${endpoint} -k -u ${heapusername}:${heappassword}
}

