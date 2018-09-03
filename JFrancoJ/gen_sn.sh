
function gen_sn() {
# genera un SN

snid=$(< /dev/urandom tr -dc ABCDEFGHJKLMNPQRSTUVWXYZZ0123456789 | head -c${1:-16})

sn1=${snid:0:4}
sn2=${snid:4:4}
sn3=${snid:8:4}
sn4=${snid:12:4}
val1=$(($(printf "%i" "'${snid:0:1}")+0))
val2=$(($(printf "%i" "'${snid:1:1}")+3))
val3=$(($(printf "%i" "'${snid:2:1}")+7))
val4=$(($(printf "%i" "'${snid:3:1}")+11))
val5=$(($(printf "%d" "'${snid:4:1}")+13))
val6=$(($(printf "%d" "'${snid:5:1}")+17))
val7=$(($(printf "%d" "'${snid:6:1}")+23))
val8=$(($(printf "%d" "'${snid:7:1}")+29))
val9=$(($(printf "%d" "'${snid:8:1}")+31))
val10=$(($(printf "%d" "'${snid:9:1}")+37))
val11=$(($(printf "%d" "'${snid:10:1}")+41))
val12=$(($(printf "%d" "'${snid:11:1}")+43))
val13=$(($(printf "%d" "'${snid:12:1}")+47))
val14=$(($(printf "%d" "'${snid:13:1}")+53))
val15=$(($(printf "%d" "'${snid:14:1}")+59))
val16=$(($(printf "%d" "'${snid:15:1}")+61))
val=$((val1+val2+val3+val4+val5+val6+val7+val8+val9+val10+val11+val12+val13+val14+val15+val16))


}

function check_prim() {
i=2;
prim=1;
while [ $i -lt $val ]
do
  if [ `expr $val % $i` -eq 0 ]
  then
      prim=0
      break
  fi
  i=`expr $i + 1`
done
}

if [ ! $(cat /root/libre_scripts/sn 2>/dev/null) ]; then
  echo "Building a Serial Number..."
  prim=0
  while [ $prim == 0 ];do
    gen_sn
    check_prim
  done

  #echo "$snid $sn1-$sn2-$sn3-$sn4 $val $prim"
  echo "Serial Number: $sn1-$sn2-$sn3-$sn4"
  echo "$sn1-$sn2-$sn3-$sn4" > /root/libre_scripts/sn
else 
  echo "SN already"
fi
