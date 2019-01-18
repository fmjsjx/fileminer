class Hash

  def keys_to_sym
    map { |k, v| [k.to_sym, v] }.to_h
  end

  def keys_to_sym!
    new_hash = keys_to_sym
    clear
    merge! new_hash
  end

end