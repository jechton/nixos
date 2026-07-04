# To add secrets:
#   Add an entry in this file
#   agenix -e [name].age ($EDITOR will open)
#   Reference in module: config.age.secrets.[name].path
#
# To edit an existing secret:
#   agenix -e [name].age
let
  personal = "age1pk5423pk642emdzj9dfjt5rppq67j3efrcnfg376ez4rwwj6t33sydue6t";
in {
  "user-password.age".publicKeys = [personal];
  "gpg-key.age".publicKeys = [personal];
}
