function validate() {
    var name = document.f1.name.value;
    var password = document.f1.password.value;
    var status = false;
    if (name == "") {
        document.getElementById("namelocation").innerHTML =
            "This field is required.";
        status = false;
    } else {
        status = true;
    }
    if (password == "") {
        document.getElementById("passwordlocation").innerHTML =
            "This field is required.";
        status = false;
    } else if (name != "admin" || password != "admin") {
        document.getElementById("passwordlocation").innerHTML =
            "Invalid username or password.";
        status = false;
    }
    return status;
}
