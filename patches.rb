class Hash
  def to_sym
    inject({}){|m,(k,v)| m[k.to_sym] = v; m}
  end
end
